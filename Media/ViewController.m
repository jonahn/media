//
//  ViewController.m
//  Media
//
//  Created by Jonathan on 2018/4/23.
//  Copyright © 2018年 JN. All rights reserved.
//

#import "ViewController.h"
#import "JNAVVideoCapture.h"
#import "JNGPUInputNode.h"
#import "GPUImageBeautifyFilter.h"
#import "JNGPUOutputNode.h"
#import "JNH264Encoder.h"

@interface ViewController ()
@property (nonatomic, strong) JNAVVideoCapture *videoCapture;
@property (nonatomic, strong) JNGPUInputNode *inputNode;
@property (nonatomic, strong) GPUImageView *displayImageView;
@property (nonatomic, strong)  GPUImageVideoCamera *videoCamera;

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) GPUImageBeautifyFilter *beautyFilter;
@property (nonatomic, strong) JNGPUOutputNode *outputNode;

@property (nonatomic, strong) JNH264Encoder *h264Encoder;
@property (nonatomic, strong)  NSFileHandle *h264fileHandle;
@property (nonatomic, strong)  NSString     *h264FilePath;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
//    [self jn_videoCaptureTestUseImageView];
    
//    [self jn_videoCaptureTestUseVideoPreviewLayer];
    
//    [self jn_videoCaptureTestUseInputImageNode];
    
//    [self jn__testOutputNode];
    
    [self jn__testH264Encoder];
    
//    [self jn__testGPUCamera];
}

- (void)jn_videoCaptureTestUseImageView
{
    self.imageView = [[UIImageView alloc] init];
    self.imageView.frame = self.view.bounds;
    [self.view addSubview:self.imageView];
    [self.view sendSubviewToBack:self.imageView];
    
    __weak typeof(self) weakSelf = self;
    self.videoCapture  = [[JNAVVideoCapture alloc] initWithPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront fps:25 outPutDataFmt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange processingCallback:^(CMSampleBufferRef sampleBuffer) {
            [weakSelf drawSampleBuffer:sampleBuffer];
    }];
}

- (void)jn_videoCaptureTestUseVideoPreviewLayer
{
    self.videoCapture  = [[JNAVVideoCapture alloc] initWithPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront fps:25 outPutDataFmt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange processingCallback:^(CMSampleBufferRef sampleBuffer) {
    }];
    AVCaptureVideoPreviewLayer *preViewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.videoCapture.videoSession];
    preViewLayer.frame = CGRectMake(0.f, 0.f, self.view.bounds.size.width, self.view.bounds.size.height);
    preViewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:preViewLayer];
}

- (void)jn_videoCaptureTestUseInputImageNode
{
    self.inputNode = [[JNGPUInputNode alloc] initWithInputFmt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    
    GPUImageView *displayImageView = [[GPUImageView alloc] init];
    displayImageView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    displayImageView.backgroundColor = [UIColor blackColor];
    displayImageView.frame = self.view.bounds;
    [self.view addSubview:displayImageView];
    [self.view sendSubviewToBack:displayImageView];
    self.displayImageView = displayImageView;

    [self.inputNode addTarget:displayImageView];
    
    __weak typeof(self) weakSelf = self;
    self.videoCapture  = [[JNAVVideoCapture alloc] initWithPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront fps:25 outPutDataFmt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange processingCallback:^(CMSampleBufferRef sampleBuffer) {
        __strong typeof(weakSelf) sSelf = weakSelf;
        [sSelf.inputNode processVideoSampleBuffer:sampleBuffer];
    }];
}

- (void)jn__testOutputNode
{
    self.inputNode = [[JNGPUInputNode alloc] initWithInputFmt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    
    GPUImageView *displayImageView = [[GPUImageView alloc] init];
    displayImageView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    displayImageView.backgroundColor = [UIColor blackColor];
    displayImageView.frame = self.view.bounds;
    [self.view addSubview:displayImageView];
    [self.view sendSubviewToBack:displayImageView];
    self.displayImageView = displayImageView;
    [self.displayImageView setHidden:YES];
    [self.inputNode addTarget:displayImageView];
    
    __weak typeof(self) weakSelf = self;
    self.videoCapture  = [[JNAVVideoCapture alloc] initWithPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront fps:25 outPutDataFmt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange processingCallback:^(CMSampleBufferRef sampleBuffer) {
        __strong typeof(weakSelf) sSelf = weakSelf;
        [sSelf.inputNode processVideoSampleBuffer:sampleBuffer];
    }];
    
    self.imageView = [[UIImageView alloc] init];
    self.imageView.frame = self.view.bounds;
    [self.view addSubview:self.imageView];
    [self.view sendSubviewToBack:self.imageView];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    self.h264FilePath = [documentsDirectory stringByAppendingPathComponent:@"TestH264.h264"];
    [fileManager removeItemAtPath:self.h264FilePath error:nil];
    [fileManager createFileAtPath:self.h264FilePath contents:nil attributes:nil];
    
    self.h264Encoder = [[JNH264Encoder alloc] init];
    self.h264Encoder.processingEncodedData = ^(NSData *sps, NSData *pps, NSData *frameData, BOOL isKeyFrame) {
        __strong typeof(weakSelf) sSelf = weakSelf;
        if (!sSelf.h264fileHandle) {
            sSelf.h264fileHandle = [NSFileHandle fileHandleForWritingAtPath:sSelf.h264FilePath];
        }
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        if (isKeyFrame) {
            [sSelf.h264fileHandle writeData:ByteHeader];
            [sSelf.h264fileHandle writeData:sps];
            [sSelf.h264fileHandle writeData:ByteHeader];
            [sSelf.h264fileHandle writeData:pps];
        }
        [sSelf.h264fileHandle writeData:ByteHeader];
        [sSelf.h264fileHandle writeData:frameData];
    };
     
    
    self.outputNode = [[JNGPUOutputNode alloc] init];
    self.outputNode.processingCallback32BGRA = ^(CVPixelBufferRef pixelBuffer, CMTime timeInfo) {
        __strong typeof(weakSelf) sSelf = weakSelf;
        [sSelf drawPixelBuffer:pixelBuffer];
        [sSelf.h264Encoder processVideoBuffer:pixelBuffer timeInfo:timeInfo];
    };
    [self.inputNode addTarget:self.outputNode];
}

- (void)jn__testH264Encoder
{
    self.inputNode = [[JNGPUInputNode alloc] initWithInputFmt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    
    GPUImageView *displayImageView = [[GPUImageView alloc] init];
    displayImageView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    displayImageView.backgroundColor = [UIColor blackColor];
    displayImageView.frame = self.view.bounds;
    [self.view addSubview:displayImageView];
    [self.view sendSubviewToBack:displayImageView];
    self.displayImageView = displayImageView;
    [self.displayImageView setHidden:YES];
    [self.inputNode addTarget:displayImageView];
    
    __weak typeof(self) weakSelf = self;
    self.videoCapture  = [[JNAVVideoCapture alloc] initWithPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront fps:25 outPutDataFmt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange processingCallback:^(CMSampleBufferRef sampleBuffer) {
        __strong typeof(weakSelf) sSelf = weakSelf;
        [sSelf.inputNode processVideoSampleBuffer:sampleBuffer];
    }];
    
    self.imageView = [[UIImageView alloc] init];
    self.imageView.frame = self.view.bounds;
    [self.view addSubview:self.imageView];
    [self.view sendSubviewToBack:self.imageView];
    
    self.outputNode = [[JNGPUOutputNode alloc] init];
    self.outputNode.processingCallback32BGRA = ^(CVPixelBufferRef pixelBuffer, CMTime timeInfo) {
        __strong typeof(weakSelf) sSelf = weakSelf;
        [sSelf drawPixelBuffer:pixelBuffer];
    };
    [self.inputNode addTarget:self.outputNode];
}

- (void)jn__testGPUCamera
{
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    
    GPUImageView *displayImageView = [[GPUImageView alloc] init];
    displayImageView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    displayImageView.backgroundColor = [UIColor blackColor];
    displayImageView.frame = self.view.bounds;
    [self.view addSubview:displayImageView];
    [self.view sendSubviewToBack:displayImageView];
    
    [self.videoCamera addTarget:displayImageView];
    [self.videoCamera startCameraCapture];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)openCamera:(UIButton *)sender {
    if (sender.selected) {
        [self.videoCapture stopCapture];
        sender.selected = NO;
    }
    else{
        [self.videoCapture startCapture];
        sender.selected = YES;
    }
}
- (IBAction)openBeautifyFilter:(UIButton *)sender {
    if (sender.selected) {
        [self.inputNode removeAllTargets];
        [self.beautyFilter removeTarget:self.displayImageView];
        [self.beautyFilter removeTarget:self.outputNode];
        [self.inputNode addTarget:self.displayImageView];
        [self.inputNode addTarget:self.outputNode];
        sender.selected = NO;
    }
    else{
        [self.inputNode removeAllTargets];
        [self.inputNode addTarget:self.beautyFilter];
        [self.beautyFilter addTarget:self.displayImageView];
        [self.beautyFilter addTarget:self.outputNode];
        sender.selected = YES;
    }
    
}
- (IBAction)h264EncodeClick:(UIButton *)sender {
    if (sender.selected) {
        [self.h264Encoder stop];
        sender.selected = NO;
    }
    else{
        [self.h264Encoder run];
        sender.selected = YES;
    }
}

- (void)drawSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef imageBuffer =  CMSampleBufferGetImageBuffer(sampleBuffer);

    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);

    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow, rgbColorSpace, kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrder32Little, provider, NULL, true, kCGRenderingIntentDefault);


    UIImage *image = [UIImage imageWithCGImage:cgImage];

    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgbColorSpace);

    NSData* imageData = UIImageJPEGRepresentation(image, 1.0);
    image = [UIImage imageWithData:imageData];
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.imageView setImage:image];
    });
}
- (void)drawPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVImageBufferRef imageBuffer =  pixelBuffer;
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, NULL);
    
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, bytesPerRow, rgbColorSpace, kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrder32Little, provider, NULL, true, kCGRenderingIntentDefault);
    
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(rgbColorSpace);
    
    NSData* imageData = UIImageJPEGRepresentation(image, 1.0);
    image = [UIImage imageWithData:imageData];
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.imageView setImage:image];
    });
}

- (GPUImageBeautifyFilter *)beautyFilter
{
    if (!_beautyFilter) {
        _beautyFilter = [[GPUImageBeautifyFilter alloc] init];
    }
    return _beautyFilter;
}
@end
