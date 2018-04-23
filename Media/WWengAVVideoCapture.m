//
//  WWengVideoCapture.m
//  ShortVideo
//
//  Created by Jonathan on 2018/4/8.
//  Copyright © 2018年 WWeng. All rights reserved.
//

#import "WWengAVVideoCapture.h"

#define WWengVideoProcessingQueue "WWeng.VideoProcessingQueue"

@interface WWengAVVideoCapture ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession *_captureSession;
    AVCaptureDevice *_videoDevice;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoDataOutput;
    dispatch_queue_t _videoProcessingQueue;
}
@property (nonatomic, copy)   AVCaptureSessionPreset sessionPreset;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, assign) UInt32 pixelFormat;
@property (nonatomic, copy)   void(^videoDataCallBack)(CMSampleBufferRef sampleBuffer);

@end

@implementation WWengAVVideoCapture

- (instancetype)initWithPreset:(AVCaptureSessionPreset)preset
                cameraPosition:(AVCaptureDevicePosition)cameraPosition
                           fps:(UInt32)fps
                 outPutDataFmt:(UInt32)fmt
            processingCallback:(void (^)(CMSampleBufferRef))callback
{
    self = [super init];
    if (self) {
        _sessionPreset = preset;
        _cameraPosition = cameraPosition;
        _fps = fps;
        _pixelFormat = fmt;
        _videoDataCallBack = callback;
        [self setupVideoProcess];
    }
    return self;
}

- (void)setupVideoProcess
{
    
    [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    //会话
    _captureSession = [[AVCaptureSession alloc] init];
    if ([_captureSession canSetSessionPreset:_sessionPreset]) {
        [_captureSession setSessionPreset:_sessionPreset];
    }
    else{
        [_captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    }
    [_captureSession beginConfiguration];
    
    //摄像头
    _videoDevice = [self cameraWithPosition:_cameraPosition];
    
    //帧数
    [_videoDevice lockForConfiguration:nil];
    [_videoDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, _fps)];
    [_videoDevice setActiveVideoMinFrameDuration:CMTimeMake(1, _fps)];
    [_videoDevice unlockForConfiguration];
    
    //input
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:nil];
    if (_videoInput && [_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
    //处理队列
    _videoProcessingQueue = dispatch_queue_create(WWengVideoProcessingQueue, DISPATCH_QUEUE_SERIAL);
    //videoDataOutput
    _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:_pixelFormat] forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    [_videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    //设置buffer返回代理和处理队列
    [_videoDataOutput setSampleBufferDelegate:self queue:_videoProcessingQueue];
    
    if ([_captureSession canAddOutput:_videoDataOutput]) {
        [_captureSession addOutput:_videoDataOutput];
    }
    [_captureSession commitConfiguration];
}

- (void)startCapture
{
    if (_captureSession) {
        [_captureSession startRunning];
        _running = YES;
    }
}

- (void)stopCapture
{
    if (_captureSession) {
        [_captureSession stopRunning];
        _running = NO;
    }
}

- (void)rotateCamera
{
    if (_cameraPosition == AVCaptureDevicePositionFront) {
        _cameraPosition = AVCaptureDevicePositionBack;
    }
    else{
        _cameraPosition = AVCaptureDevicePositionFront;
    }
    AVCaptureDevice *newDevice = [self cameraWithPosition:_cameraPosition];
    [_captureSession beginConfiguration];
    [_captureSession removeInput:_videoInput];
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newDevice error:nil];
    [_captureSession addInput:_videoInput];
    [_captureSession commitConfiguration];
}

- (void)setFps:(UInt32)fps
{
    _fps = fps;
    if (_videoDevice) {
        [_videoDevice lockForConfiguration:nil];
        [_videoDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, _fps)];
        [_videoDevice setActiveVideoMinFrameDuration:CMTimeMake(1, _fps)];
        [_videoDevice unlockForConfiguration];
    }
}

- (AVCaptureDevice *)videoDevice
{
    return _videoDevice;
}

- (AVCaptureSession *)videoSession
{
    return _captureSession;
}

// 这是获取前后摄像头对象的方法
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.videoDataCallBack) {
        self.videoDataCallBack(sampleBuffer);
    }
}

@end
