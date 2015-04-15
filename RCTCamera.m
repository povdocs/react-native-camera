#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import "RCTCamera.h"
#import "RCTCameraManager.h"
#import "RCTLog.h"
#import "RCTUtils.h"
#import "ViewfinderView.h"
#import "UIImage+Resize.h"
#import <AVFoundation/AVFoundation.h>

NSString *const RNCameraEventRecordStart = @"recordingStarted";
NSString *const RNCameraEventRecordEnd = @"recordingEnded";
NSString *const RNCameraEventFrameRateChange = @"frameRateChange";

@implementation RCTCamera
{
    /* Required to publish events */
    RCTEventDispatcher *_eventDispatcher;
}

- (BOOL)getIsRecording
{
    return _isRecording;
}

- (void)setAspect:(NSString *)aspect
{
    [(AVCaptureVideoPreviewLayer *)[[self viewfinder] layer] setVideoGravity:aspect];
}

- (void)setType:(NSInteger)camera
{
    if ([[self session] isRunning] && !_isRecording) {
        [self changeCamera:camera];
    }
    else {
        [self setPresetCamera:camera];
    }
}

- (void)setOrientation:(NSInteger)orientation
{
    [self changeOrientation:orientation];
}

- (void)setFrameRate:(double)frameRate
{
    _frameRate = frameRate;
    if ([[self session] isRunning] && !_isRecording) {
        [self changeFrameRate:frameRate];
    }
}

- (double)getCurrentFrameRate
{
    AVCaptureDeviceInput *input = [self captureDeviceInput];
    if (input != nil) {
        AVCaptureDevice *camera = [input device];
        if (camera != nil) {
            double min = CMTimeGetSeconds(camera.activeVideoMinFrameDuration);
            double max = CMTimeGetSeconds(camera.activeVideoMaxFrameDuration);
            return 2.0 / (min + max);
        }
    }

    return _frameRate;
}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    _isRecording = NO;

    if ((self = [super init])) {
        _eventDispatcher = eventDispatcher;

        [self setViewfinder:[[ViewfinderView alloc] init]];

        [self setSession:[[AVCaptureSession alloc] init]];
        [[self session] setSessionPreset:AVCaptureSessionPresetHigh];

        [[self viewfinder] setSession:[self session]];
        [self addSubview:[self viewfinder]];

        [[self session] startRunning];

        dispatch_queue_t sessionQueue = dispatch_queue_create("cameraManagerQueue", DISPATCH_QUEUE_SERIAL);
        [self setSessionQueue:sessionQueue];

        dispatch_async(sessionQueue, ^{
            NSError *error = nil;

            NSInteger presetCamera = [self presetCamera];

            if ([self presetCamera] == AVCaptureDevicePositionUnspecified) {
                presetCamera = AVCaptureDevicePositionBack;
            }

            //Set up video capture device
            AVCaptureDevice *captureDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:presetCamera];
            AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];

            if (error)
            {
                NSLog(@"%@", error);
            }

            if ([[self session] canAddInput:captureDeviceInput])
            {
                [[self session] addInput:captureDeviceInput];
                [self setCaptureDeviceInput:captureDeviceInput];
            }

            //Set up audio capture device
            //todo: don't do this until we need it?
            AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];

            AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
            
            if (error)
            {
                NSLog(@"%@", error);
            }
            
            if ([[self session] canAddInput:audioDeviceInput])
            {
                [[self session] addInput:audioDeviceInput];
                [self setAudioDeviceInput:audioDeviceInput];
            }
            
            //set up still image capture output
            AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
            if ([[self session] canAddOutput:stillImageOutput])
            {
                [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
                [[self session] addOutput:stillImageOutput];
                [self setStillImageOutput:stillImageOutput];
            }
            
            //set up movie output
            AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
            
            Float64 totalSeconds = 60.0;
            int32_t preferredTimeScale = 30; //Frames per second
            CMTime maxDuration = CMTimeMakeWithSeconds(totalSeconds, preferredTimeScale);
            movieFileOutput.maxRecordedDuration = maxDuration;

            if ([[self session] canAddOutput:movieFileOutput]) {
                [[self session] addOutput:movieFileOutput];
                [self setMovieFileOutput:movieFileOutput];
            }

            __weak RCTCamera *weakSelf = self;
            [self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:[self session] queue:nil usingBlock:^(NSNotification *note) {
                RCTCamera *strongSelf = weakSelf;
                dispatch_async([strongSelf sessionQueue], ^{
                    // Manually restarting the session since it must have been stopped due to an error.
                    [[strongSelf session] startRunning];
                });
            }]];
        });
    }
    return self;
}

- (NSArray *)reactSubviews
{
    NSArray *subviews = @[[self viewfinder]];
    return subviews;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [[self viewfinder] setFrame:[self bounds]];
}

- (void)insertReactSubview:(UIView *)view atIndex:(NSInteger)atIndex
{
    [self insertSubview:view atIndex:atIndex + 1];
    return;
}

- (void)removeReactSubview:(UIView *)subview
{
    [subview removeFromSuperview];
    return;
}

- (void)removeFromSuperview
{
    _eventDispatcher = nil;
}

- (void)changeFrameRate:(double)frameRate {
    dispatch_async([self sessionQueue], ^{
        NSError *error;
        AVCaptureDevice *camera = [[self captureDeviceInput] device];
        if (![camera lockForConfiguration:&error]) {
            NSLog(@"Could not lock device %@ for configuration: %@", camera, error);
            return;
        }

        double oldFrameRate = [self getCurrentFrameRate];
        const double epsilon = 0.00002;
        if (ABS(oldFrameRate - frameRate) < epsilon) {
            //no need to go through all this business
            return;
        }

        AVCaptureDeviceFormat *format = [camera activeFormat];
        CMTime high = kCMTimeZero;
        CMTime low = kCMTimeIndefinite;
        CMTime desiredDuration = CMTimeMultiplyByFloat64(CMTimeMake(1, 1), 1.0 / frameRate);
        CMTime frameDuration = desiredDuration;

        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {

            low = CMTimeMinimum(low, range.minFrameDuration);
            high = CMTimeMaximum(high, range.maxFrameDuration);

            if (CMTimeCompare(low, desiredDuration) <= 0 && CMTimeCompare(high, desiredDuration) >= 0) {
                frameDuration = desiredDuration;
                break;
            } else {
                CMTime lowDiff = CMTimeAbsoluteValue(CMTimeSubtract(low, desiredDuration));
                CMTime highDiff = CMTimeAbsoluteValue(CMTimeSubtract(high, desiredDuration));
                if (CMTimeCompare(lowDiff, highDiff) < 0) {
                    frameDuration = low;
                } else {
                    frameDuration = high;
                }
            }
        }

        camera.activeVideoMaxFrameDuration = frameDuration;
        camera.activeVideoMinFrameDuration = frameDuration;

        double newFrameRate = 1.0 / CMTimeGetSeconds(frameDuration);
        //todo: use value of last event fired instead of oldFrameRate
        if (ABS(newFrameRate - oldFrameRate) > epsilon) {
            NSLog(@"Frame rate changed from %f to %f", oldFrameRate, newFrameRate);
            [_eventDispatcher
             sendInputEventWithName:RNCameraEventFrameRateChange
             body:@{
                    @"target": self.reactTag,
                    @"frameRate": [NSNumber numberWithDouble:frameRate]
                    }];
        }

        [camera unlockForConfiguration];
    });
}

- (void)changeCamera:(NSInteger)camera {
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *currentCaptureDevice = [[self captureDeviceInput] device];
        AVCaptureDevicePosition position = (AVCaptureDevicePosition)camera;
        AVCaptureDevice *captureDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:(AVCaptureDevicePosition)position];

        NSError *error = nil;
        AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];

        if (error)
        {
            NSLog(@"%@", error);
        }

        [[self session] beginConfiguration];

        [[self session] removeInput:[self captureDeviceInput]];

        if ([[self session] canAddInput:captureDeviceInput])
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentCaptureDevice];

            [self setFlashMode:AVCaptureFlashModeAuto forDevice:captureDevice];

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
            [[self session] addInput:captureDeviceInput];
            [self setCaptureDeviceInput:captureDeviceInput];
        }
        else
        {
            [[self session] addInput:[self captureDeviceInput]];
        }


        [[self session] commitConfiguration];
        [self changeFrameRate:_frameRate];
    });
}

- (void)changeOrientation:(NSInteger)orientation {
    [[(AVCaptureVideoPreviewLayer *)[[self viewfinder] layer] connection] setVideoOrientation:orientation];

    AVCaptureConnection *captureConnection = [[self movieFileOutput] connectionWithMediaType:AVMediaTypeVideo];
    
    if ([captureConnection isVideoOrientationSupported]) {
        [captureConnection setVideoOrientation:orientation];
    }
}

- (void)takePicture:(RCTResponseSenderBlock)callback {
    dispatch_async([self sessionQueue], ^{

        // Update the orientation on the still image output video connection before capturing.
        [[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self viewfinder] layer] connection] videoOrientation]];

        // Flash set to Auto for Still Capture
        [self setFlashMode:AVCaptureFlashModeAuto forDevice:[[self captureDeviceInput] device]];

        // Capture a still image.
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {

            if (imageDataSampleBuffer)
            {
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [UIImage imageWithData:imageData];
                UIImage *rotatedImage = [image resizedImage:CGSizeMake(image.size.width, image.size.height) interpolationQuality:kCGInterpolationDefault];
                NSString *imageBase64 = [UIImageJPEGRepresentation(rotatedImage, 1.0) base64EncodedStringWithOptions:0];
                callback(@[[NSNull null], imageBase64]);
            }
            else {
                callback(@[RCTMakeError([error description], nil, nil)]);
            }
        }];
    });
}

- (void)startRecording
{
    if (_isRecording) {
        return;
    }
    
    NSLog(@"start recording");
    //todo: fire event
    _isRecording = YES;

    //fire event
    [_eventDispatcher
     sendInputEventWithName:RNCameraEventRecordStart
     body:@{
            //todo: fill in data here. destination file name, maybe? misc camera config
            @"target": self.reactTag
            }];

    //create temporary url as recording destination
    //todo: get recording destination from a param
    NSString *outputPath = [[NSString alloc] initWithFormat:@"%@%s", NSTemporaryDirectory(), "@output.mov"];
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            //todo: handle error if necessary
        }
    }
    
    //start recording
    [[self movieFileOutput] startRecordingToOutputFileURL:outputURL recordingDelegate:self];
}

- (void)stopRecording
{
    if (!_isRecording) {
        return;
    }
    
    NSLog(@"Stop recording");
    _isRecording = NO;
    [[self movieFileOutput] stopRecording];
}

- (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];

    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
        {
            captureDevice = device;
            break;
        }
    }

    return captureDevice;
}


- (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ([device hasFlash] && [device isFlashModeSupported:flashMode])
    {
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    }
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake(.5, .5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *device = [[self captureDeviceInput] device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
            {
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
            {
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    });
}

- (void) captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{

    _isRecording = NO;

    BOOL recordedSuccessfully = YES;
    if ([error code] != noErr) {
        //something went wrong. check if recording was successful
        id value = [[error userInfo] objectForKey:AVErrorRecordingSuccessfullyFinishedKey];
        if (value) {
            recordedSuccessfully = [value boolValue];
        }
    }
    
    if (recordedSuccessfully) {
        [_eventDispatcher
         sendInputEventWithName:RNCameraEventRecordEnd
         body:@{
                //todo: fill in data here. destination file name, maybe? duration
                @"target": self.reactTag
        }];

        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputFileURL]) {
            [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error)
             {
                 if (error) {
                     //todo: handle write error
                 }
                 
                 //todo: send event back to JS
             }];
        }
    } else {
        //todo: fire error event?
    }
}


@end
