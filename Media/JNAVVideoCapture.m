//
//  JNVideoCapture.m
//  ShortVideo
//
//  Created by Jonathan on 2018/4/8.
//  Copyright © 2018年 JN. All rights reserved.
//

#import "JNAVVideoCapture.h"

#define JNVideoProcessingQueue "JN.VideoProcessingQueue"

@interface JNAVVideoCapture ()<AVCaptureVideoDataOutputSampleBufferDelegate>
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

@implementation JNAVVideoCapture

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
        [self jn__setupVideoProcess];
    }
    return self;
}

- (void)jn__setupVideoProcess
{
//    [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    //会话
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession beginConfiguration];
    
    //摄像头
    _videoDevice = [self jn__cameraWithPosition:_cameraPosition];
    
    //帧数
    [_videoDevice lockForConfiguration:nil];
    [_videoDevice setActiveVideoMaxFrameDuration:CMTimeMake(1, _fps)];
    [_videoDevice setActiveVideoMinFrameDuration:CMTimeMake(1, _fps)];
    [_videoDevice unlockForConfiguration];
    
    //input
    NSError *error = nil;
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:&error];
    if (_videoInput && [_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
    //处理队列
    _videoProcessingQueue = dispatch_queue_create(JNVideoProcessingQueue, NULL);
    //videoDataOutput
    _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoDataOutput.videoSettings = @{
                                       (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey:@(_pixelFormat)
                                       };
    [_videoDataOutput setAlwaysDiscardsLateVideoFrames:NO];
    //设置buffer返回代理和处理队列
    [_videoDataOutput setSampleBufferDelegate:self queue:_videoProcessingQueue];
    
    if ([_captureSession canAddOutput:_videoDataOutput]) {
        [_captureSession addOutput:_videoDataOutput];
    }
    
    AVCaptureConnection *connection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    if ([connection isVideoStabilizationSupported]) {
        connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    connection.videoScaleAndCropFactor = connection.videoMaxScaleAndCropFactor;
    
    
    if ([_captureSession canSetSessionPreset:_sessionPreset]) {
        [_captureSession setSessionPreset:_sessionPreset];
    }
    else{
        [_captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
    }
    
    [_captureSession commitConfiguration];
}

- (void)startCapture
{
    if(_running){
        return;
    }
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
    AVCaptureDevice *newDevice = [self jn__cameraWithPosition:_cameraPosition];
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
- (AVCaptureDevice *)jn__cameraWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.videoDataCallBack) {
        self.videoDataCallBack(sampleBuffer);
    }
}

@end
