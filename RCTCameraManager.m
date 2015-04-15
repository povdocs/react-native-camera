#import "RCTCameraManager.h"
#import "RCTCamera.h"
#import "RCTBridge.h"
#import "RCTUtils.h"
#import "UIView+React.h"
#import <AVFoundation/AVFoundation.h>

@implementation RCTCameraManager

@synthesize bridge = _bridge;

- (UIView *)view
{
    [self setCurrentCamera:[[RCTCamera alloc] initWithEventDispatcher:self.bridge.eventDispatcher]];
    return _currentCamera;
}

RCT_EXPORT_VIEW_PROPERTY(aspect, NSString);
RCT_EXPORT_VIEW_PROPERTY(type, NSInteger);
RCT_EXPORT_VIEW_PROPERTY(orientation, NSInteger);
RCT_EXPORT_VIEW_PROPERTY(frameRate, double);
RCT_EXPORT_VIEW_PROPERTY(isRecording, NSString);

- (NSDictionary *)constantsToExport
{
    return @{
      @"aspects": @{
        @"Stretch": AVLayerVideoGravityResize,
        @"Fit": AVLayerVideoGravityResizeAspect,
        @"Fill": AVLayerVideoGravityResizeAspectFill
      },
      @"cameras": @{
        @"Front": @(AVCaptureDevicePositionFront),
        @"Back": @(AVCaptureDevicePositionBack)
      },
      @"orientations": @{
        @"LandscapeLeft": @(AVCaptureVideoOrientationLandscapeLeft),
        @"LandscapeRight": @(AVCaptureVideoOrientationLandscapeRight),
        @"Portrait": @(AVCaptureVideoOrientationPortrait),
        @"PortraitUpsideDown": @(AVCaptureVideoOrientationPortraitUpsideDown)
      }
    };
}

- (NSDictionary *)customDirectEventTypes
{
    return @{
        RNCameraEventRecordStart: @{
            @"registrationName": @"onRecordStart"
        },
        RNCameraEventRecordEnd: @{
            @"registrationName": @"onRecordEnd"
        },
        RNCameraEventFrameRateChange: @{
            @"registrationName": @"onFrameRateChange"
        }
    };
}


- (void)checkDeviceAuthorizationStatus:(RCTResponseSenderBlock) callback {
    RCT_EXPORT();
    NSString *mediaType = AVMediaTypeVideo;

    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        callback(@[[NSNull null], @(granted)]);
    }];
}


- (void)switchCamera:(NSInteger)camera
{
    RCT_EXPORT();
    [_currentCamera changeCamera:camera];
}

- (void)setOrientation:(NSInteger)orientation
{
    RCT_EXPORT();
    [_currentCamera changeOrientation:orientation];
}

- (void)takePicture:(RCTResponseSenderBlock) callback {
    RCT_EXPORT();
    [_currentCamera takePicture:callback];
}

- (void)startRecording {
    RCT_EXPORT();
    [_currentCamera startRecording];
}

- (void)stopRecording {
    RCT_EXPORT();
    [_currentCamera stopRecording];
}

@end
