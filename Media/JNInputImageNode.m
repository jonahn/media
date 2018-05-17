//
//  JNImageOutputConnection.m
//  Media
//
//  Created by Jonathan on 2018/5/16.
//  Copyright © 2018年 JN. All rights reserved.
//

#import "JNInputImageNode.h"

@interface JNInputImageNode ()
{
    const GLfloat *_preferredConversion;
}
@property (nonatomic, assign) UInt32 fmt;
@property (nonatomic, strong) dispatch_semaphore_t frameRenderingSemaphore;
@property (nonatomic, strong) GLProgram *yuvConversionProgram;
@property (nonatomic, assign) GLint yuvConversionMatrixUniform;
@property (nonatomic, assign) GLint yuvConversionPositionAttribute;
@property (nonatomic, assign) GLint yuvConversionTextureCoordinateAttribute;
@property (nonatomic, assign) GLint yuvConversionLuminanceTextureUniform;
@property (nonatomic, assign) GLint yuvConversionChrominanceTextureUniform;

@property (nonatomic, assign) GPUImageRotationMode outputRotation;
@end

@implementation JNInputImageNode
- (instancetype)initWithInputFmt:(UInt32)fmt
{
    self = [super init];
    if (self) {
        _fmt = fmt;
        [self jn__setupInputImageNode];
    }
    return self;
}

- (void)jn__setupInputImageNode
{
    _frameRenderingSemaphore = dispatch_semaphore_create(1);
    _outputRotation = kGPUImageNoRotation;
    _preferredConversion = kColorConversion709;
    __weak typeof(self) weakSelf = self;
    runSynchronouslyOnVideoProcessingQueue(^{
        __strong typeof(weakSelf) sSelf = weakSelf;
            [GPUImageContext useImageProcessingContext];
            if (sSelf.fmt == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                sSelf.yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVFullRangeConversionForLAFragmentShaderString];
            }
            else{
               sSelf.yuvConversionProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImageYUVVideoRangeConversionForLAFragmentShaderString];
            }
            if (!sSelf.yuvConversionProgram.initialized) {
                [sSelf.yuvConversionProgram addAttribute:@"position"];
                [sSelf.yuvConversionProgram addAttribute:@"inputTextureCoordinate"];
                if (![sSelf.yuvConversionProgram link]){
                    NSString *progLog = [sSelf.yuvConversionProgram programLog];
                    NSLog(@"Program link log: %@", progLog);
                    NSString *fragLog = [sSelf.yuvConversionProgram fragmentShaderLog];
                    NSLog(@"Fragment shader compile log: %@", fragLog);
                    NSString *vertLog = [sSelf.yuvConversionProgram vertexShaderLog];
                    NSLog(@"Vertex shader compile log: %@", vertLog);
                    sSelf.yuvConversionProgram = nil;
                    NSAssert(NO, @"Filter shader link failed");
                }
            }
            sSelf.yuvConversionPositionAttribute = [sSelf.yuvConversionProgram attributeIndex:@"position"];
            sSelf.yuvConversionTextureCoordinateAttribute = [sSelf.yuvConversionProgram attributeIndex:@"inputTextureCoordinate"];
            sSelf.yuvConversionLuminanceTextureUniform = [sSelf.yuvConversionProgram uniformIndex:@"luminanceTexture"];
            sSelf.yuvConversionChrominanceTextureUniform = [sSelf.yuvConversionProgram uniformIndex:@"chrominanceTexture"];
            sSelf.yuvConversionMatrixUniform = [sSelf.yuvConversionProgram uniformIndex:@"colorConversionMatrix"];
            [GPUImageContext setActiveShaderProgram:sSelf.yuvConversionProgram];
            glEnableVertexAttribArray(sSelf.yuvConversionPositionAttribute);
            glEnableVertexAttribArray(sSelf.yuvConversionTextureCoordinateAttribute);
    });
}

- (void)dealloc
{
    // ARC forbids explicit message send of 'release'; since iOS 6 even for dispatch_release() calls: stripping it out in that case is required.
#if !OS_OBJECT_USE_OBJC
    if (frameRenderingSemaphore != NULL)
    {
        dispatch_release(frameRenderingSemaphore);
    }
#endif
}

#pragma mark -
#pragma mark Managing targets

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;
{
    [super addTarget:newTarget atTextureLocation:textureLocation];
    [newTarget setInputRotation:kGPUImageNoRotation atIndex:textureLocation];
}

- (void)updateTargetsForVideoCameraUsingCacheTextureAtWidth:(int)bufferWidth height:(int)bufferHeight time:(CMTime)currentTime;
{
    
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled]){
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            if (currentTarget != self.targetToIgnoreForUpdates){
                [currentTarget setInputRotation:self.outputRotation atIndex:textureIndexOfTarget];
                [currentTarget setInputSize:CGSizeMake(bufferWidth, bufferHeight) atIndex:textureIndexOfTarget];
                if ([currentTarget wantsMonochromeInput]){
                    [currentTarget setCurrentlyReceivingMonochromeInput:YES];
                    [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
                }
                else{
                    [currentTarget setCurrentlyReceivingMonochromeInput:NO];
                    [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
                }
            }
            else{
                [currentTarget setInputRotation:self.outputRotation atIndex:textureIndexOfTarget];
                [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
            }
        }
    }
    [outputFramebuffer unlock];
    outputFramebuffer = nil;
    for (id<GPUImageInput> currentTarget in targets)
    {
        if ([currentTarget enabled]){
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            if (currentTarget != self.targetToIgnoreForUpdates){
                [currentTarget newFrameReadyAtTime:currentTime atIndex:textureIndexOfTarget];
            }
        }
    }
}

- (void)hanleVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
{
//    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferWidth = (int) CVPixelBufferGetWidth(cameraFrame);
    int bufferHeight = (int) CVPixelBufferGetHeight(cameraFrame);
    CFTypeRef colorAttachments = CVBufferGetAttachment(cameraFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    if (colorAttachments != NULL){
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo){
            if (self.fmt == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                _preferredConversion = kColorConversion601FullRange;
            }
            else{
                _preferredConversion = kColorConversion601;
            }
        }
        else{
            _preferredConversion = kColorConversion709;
        }
    }
    else{
        if (self.fmt == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            _preferredConversion = kColorConversion601FullRange;
        }
        else{
            _preferredConversion = kColorConversion601;
        }
    }
    
    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    [GPUImageContext useImageProcessingContext];
    
    if ([GPUImageContext supportsFastTextureUpload])
    {
        CVOpenGLESTextureRef luminanceTextureRef = NULL;
        CVOpenGLESTextureRef chrominanceTextureRef = NULL;
        
        //        if (captureAsYUV && [GPUImageContext deviceSupportsRedTextures])
        if (CVPixelBufferGetPlaneCount(cameraFrame) > 0) // Check for YUV planar inputs to do RGB conversion
        {
            CVPixelBufferLockBaseAddress(cameraFrame, 0);
            
            
            CVReturn err;
            // Y-plane
            glActiveTexture(GL_TEXTURE4);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            }
            else
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            
            GLuint luminanceTexture = CVOpenGLESTextureGetName(luminanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, luminanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
            // UV-plane
            glActiveTexture(GL_TEXTURE5);
            if ([GPUImageContext deviceSupportsRedTextures])
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            }
            else
            {
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
            }
            if (err)
            {
                NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
            }
            
            GLuint chrominanceTexture = CVOpenGLESTextureGetName(chrominanceTextureRef);
            glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            [self convertYUVToRGBOutputLuminanceTexture:luminanceTexture chrominanceTexture:chrominanceTexture imageBufferWidth:bufferWidth imageBufferHeight:bufferHeight];
            [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:bufferWidth height:bufferHeight time:currentTime];
            CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
            CFRelease(luminanceTextureRef);
            CFRelease(chrominanceTextureRef);
        }
    }
    else{
        CVPixelBufferLockBaseAddress(cameraFrame, 0);
        int bytesPerRow = (int) CVPixelBufferGetBytesPerRow(cameraFrame);
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(bytesPerRow / 4, bufferHeight) onlyTexture:YES];
        [outputFramebuffer activateFramebuffer];
        
        glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
        
        // Using BGRA extension to pull in video frame data directly
        // The use of bytesPerRow / 4 accounts for a display glitch present in preview video frames when using the photo preset on the camera
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bytesPerRow / 4, bufferHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(cameraFrame));
        
        [self updateTargetsForVideoCameraUsingCacheTextureAtWidth:bytesPerRow / 4 height:bufferHeight time:currentTime];
        
        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    }
}

- (void)convertYUVToRGBOutputLuminanceTexture:(GLuint)luminanceTexture chrominanceTexture:(GLuint)chrominanceTexture imageBufferWidth:(int)imageBufferWidth imageBufferHeight:(int)imageBufferHeight
{
    [GPUImageContext setActiveShaderProgram:self.yuvConversionProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:CGSizeMake(imageBufferWidth, imageBufferHeight) textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
    glActiveTexture(GL_TEXTURE4);
    glBindTexture(GL_TEXTURE_2D, luminanceTexture);
    glUniform1i(self.yuvConversionLuminanceTextureUniform, 4);
    
    glActiveTexture(GL_TEXTURE5);
    glBindTexture(GL_TEXTURE_2D, chrominanceTexture);
    glUniform1i(self.yuvConversionChrominanceTextureUniform, 5);
    
    glUniformMatrix3fv(self.yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);
    
    glVertexAttribPointer(self.yuvConversionPositionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(self.yuvConversionTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [GPUImageFilter textureCoordinatesForRotation:kGPUImageNoRotation]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (dispatch_semaphore_wait(self.frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        return;
    }
    CFRetain(sampleBuffer);
    runSynchronouslyOnVideoProcessingQueue(^{
        [self hanleVideoSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
        dispatch_semaphore_signal(self.frameRenderingSemaphore);
    });
}
@end
