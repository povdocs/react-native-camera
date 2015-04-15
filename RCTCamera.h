#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ViewfinderView.h"
#import "UIView+React.h"

@class RCTCameraManager;

@interface RCTCamera : UIView
    <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic) BOOL isRecording;
@property (nonatomic) ViewfinderView *viewfinder;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *captureDeviceInput;
@property (nonatomic) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) id runtimeErrorHandlingObserver;
@property (nonatomic) NSInteger presetCamera;
@property (nonatomic) float frameRate;

- (void)changeCamera:(NSInteger)camera;
- (void)changeOrientation:(NSInteger)orientation;
- (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position;
- (void)takePicture:(RCTResponseSenderBlock)callback;
- (void)startRecording;
- (void)stopRecording;

@end
