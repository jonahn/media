# media
iOS media tool

实现功能
1.  基于 AVCaptureSession 视频采集。（已验证） JNAVVideoCapture
2. 基于 AudioUnit的音频采集。（未验证） JNAUAudioCapture
3. 基于GPUImage的视频流处理     JNGPUInputNode
    美颜来自https://github.com/Guikunzhi/BeautifyFaceDemo
4. GPUImage处理后输出buffer      JNGPUOutputNode
5. 视频编码（硬编VideoToolBox）
6. 音频编码 (硬编toolbox)
7. lame.framework  mp3编码
