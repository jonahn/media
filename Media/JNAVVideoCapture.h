//
//  JNVideoCapture.h
//  ShortVideo
//
//  Created by Jonathan on 2018/4/8.
//  Copyright © 2018年 JN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface JNAVVideoCapture : NSObject

//会话
@property (nonatomic, readonly, strong) AVCaptureSession *videoSession;
//摄像头
@property (nonatomic, readonly, strong) AVCaptureDevice *videoDevice;
//是否在工作
@property (nonatomic, readonly, assign) BOOL running;
//帧数  默认15帧
@property (nonatomic, assign) UInt32 fps;


/**
 初始化视频采集
 
 @param preset 分辨率 AVCaptureSessionPreset1280x720
 @param cameraPosition 相机位置 AVCaptureDevicePositionFront
 @param fps 帧数
 @param fmt 输出视频格式
 - kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
 - kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
 - kCVPixelFormatType_32BGRA
 @param callback buffer输出
 @return 创建实例
 */
- (instancetype)initWithPreset:(AVCaptureSessionPreset)preset
                cameraPosition:(AVCaptureDevicePosition)cameraPosition
                           fps:(UInt32)fps
                 outPutDataFmt:(UInt32)fmt
            processingCallback:(void(^)(CMSampleBufferRef sampleBuffer))callback;


/**
 启动视频采集
 */
- (void)startCapture;

/**
 停止
 */
- (void)stopCapture;


/**
 旋转摄像头
 */
- (void)rotateCamera;

@end
