/**
 The MIT License (MIT)
 
 Copyright (c) 2015 DreamCao
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

#import "DMAudioMerge.h"


@import AVFoundation;

#if DEBUG
#   define DMAMLog(...)  NSLog(__VA_ARGS__)
#else
#   define DMAMLog(...)
#endif

#define kSampleRate             (16000)
#define kNumberOfChannel        (2)
#define kBitsPerSample          (16)

#define kBufferByteSize             (32768)

//关闭文件句柄
#define AudioFileDispose(FileRef)   do {\
                                        if (NULL != FileRef)\
                                        {\
                                            ExtAudioFileDispose(FileRef);\
                                            FileRef = NULL;\
                                        }\
                                    } while(0)

@interface DMAudioMerge ()

@property (nonatomic, assign, getter=isCancel) BOOL cancel;

@end

/**
 AudioStreamBasicDescription:
 Float64             mSampleRate;       采样率, eg. 44100
 AudioFormatID       mFormatID;         格式, eg. kAudioFormatLinearPCM
 AudioFormatFlags    mFormatFlags;      标签格式, eg. kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
 UInt32              mBytesPerPacket;   每个Packet的Bytes数量, eg. 2
 UInt32              mFramesPerPacket;  每个Packet的帧数量, eg. 1
 UInt32              mBytesPerFrame;    (mBitsPerChannel / 8 * mChannelsPerFrame) 每帧的Byte数, eg. 2
 UInt32              mChannelsPerFrame; 1:单声道；2:立体声, eg. 1
 UInt32              mBitsPerChannel;   语音每采样点占用位数[8/16/24/32], eg. 16
 UInt32              mReserved;         保留
 */

@implementation DMAudioMerge
{
    AudioStreamBasicDescription m_srcFormat1;
    AudioStreamBasicDescription m_srcFormat2;
    
    ExtAudioFileRef m_srcFileRef1;
    ExtAudioFileRef m_srcFileRef2;
    ExtAudioFileRef m_destFileRef;
    
    AudioBufferList m_srcBufList1;
    AudioBufferList m_srcBufList2;
    AudioBufferList m_destBufList;
    
    UInt32 m_numOfSrcFrames1;
    UInt32 m_numOfSrcFrames2;
    UInt32 m_numOfDestFrames;

    SInt8 m_srcBuffer1[kBufferByteSize];
    SInt8 m_srcBuffer2[kBufferByteSize];
    SInt8 m_destBuffer[kBufferByteSize];
}

- (void)dealloc
{
    DMAMLog(@"%@ dealloc", [self class]);
}

+ (instancetype)audioMerge
{
    return [[self alloc] init];
}

+ (instancetype)audioMergeDestFile:(NSString *)destFile
                          srcFile1:(NSString *)file1
                          srcFile2:(NSString *)file2
{
    return [[self alloc] initWithDestFile:destFile
                                 srcFile1:file1
                                 srcFile2:file2];
}

+ (instancetype)audioMergeDestFile:(NSString *)destFile
                          srcFile1:(NSString *)file1
                    srcFile1Volume:(float)file1Volume
                          srcFile2:(NSString *)file2
                    srcFile2Volume:(float)file2Volume
{
    return [[self alloc] initWithDestFile:destFile
                                 srcFile1:file1
                           srcFile1Volume:file1Volume
                                 srcFile2:file2
                           srcFile2Volume:file2Volume];
}

+ (instancetype)audioMergeDestFile:(NSString *)destFile
                    destFileVolume:(float)destFileVolume
                          srcFile1:(NSString *)file1
                    srcFile1Volume:(float)file1Volume
                          srcFile2:(NSString *)file2
                    srcFile2Volume:(float)file2Volume
{
    return [[self alloc] initWithDestFile:destFile
                           destFileVolume:destFileVolume
                                 srcFile1:file1
                           srcFile1Volume:file1Volume
                                 srcFile2:file2
                           srcFile2Volume:file2Volume];
}

- (instancetype)init
{
    return [self initWithDestFile:nil
                         srcFile1:nil
                         srcFile2:nil];
}

- (instancetype)initWithDestFile:(NSString *)destFile
                        srcFile1:(NSString *)file1
                        srcFile2:(NSString *)file2
{
    return [self initWithDestFile:destFile
                   destFileVolume:1.0
                         srcFile1:file1
                   srcFile1Volume:1.0
                         srcFile2:file2
                   srcFile2Volume:1.0];
}

- (instancetype)initWithDestFile:(NSString *)destFile
                        srcFile1:(NSString *)file1
                  srcFile1Volume:(float)file1Volume
                        srcFile2:(NSString *)file2
                  srcFile2Volume:(float)file2Volume
{
    return [self initWithDestFile:destFile
                   destFileVolume:1.0
                         srcFile1:file1
                   srcFile1Volume:file1Volume
                         srcFile2:file2
                   srcFile2Volume:file2Volume];
}

- (instancetype)initWithDestFile:(NSString *)destFile
                  destFileVolume:(float)destFileVolume
                        srcFile1:(NSString *)file1
                  srcFile1Volume:(float)file1Volume
                        srcFile2:(NSString *)file2
                  srcFile2Volume:(float)file2Volume
{
    self = [super init];
    if (self)
    {
        [self parameterInit];
        
        self.m_srcFile1 = file1;
        self.m_srcFile2 = file2;
        self.m_file1Volume = file1Volume;
        self.m_file2Volume = file2Volume;
        self.m_destFileVolume = destFileVolume;
        self.m_destFile = destFile;
    }
    
    return self;
}

/**
 *  打开源始文件
 *
 *  @return YES / NO
 */
- (BOOL)srcFileOpen
{
    CFURLRef srcUrlRef1 = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)self.m_srcFile1, kCFURLPOSIXPathStyle, false);
    CFURLRef srcUrlRef2 = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)self.m_srcFile2, kCFURLPOSIXPathStyle, false);
    
    AudioFileDispose(m_srcFileRef1);
    AudioFileDispose(m_srcFileRef2);
    OSStatus openErr1 = ExtAudioFileOpenURL(srcUrlRef1, &m_srcFileRef1);
    OSStatus openErr2 = ExtAudioFileOpenURL(srcUrlRef2, &m_srcFileRef2);
    
    CFRelease(srcUrlRef1);
    CFRelease(srcUrlRef2);
    
    if (openErr1 != noErr
        || openErr2 != noErr)
    {
        return NO;
    }
    
    return YES;
}

/**
 *  创建目标文件
 *
 *  @return YES / NO
 */
- (BOOL)destFileCreate
{
    if ([self.delegate respondsToSelector:@selector(audioMergeCreateDestFile:)])
    { //由代理去创建文件
        return [self.delegate audioMergeCreateDestFile:self];
    }
    
    CFURLRef dstUrlRef = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)self.m_destFile, kCFURLPOSIXPathStyle, false);
    
    AudioFileDispose(m_destFileRef);
    AudioStreamBasicDescription format = self.m_destFormat;
    OSStatus err = ExtAudioFileCreateWithURL(dstUrlRef, kAudioFileWAVEType, &format, NULL, kAudioFileFlags_EraseFile, &m_destFileRef);
    if (err != noErr)
    {
        return NO;
    }
    
    return YES;
}

/**
 *  删除目标文件
 */
- (void)deleteDestFile
{
    if (nil != self.m_destFile)
    {
        [[NSFileManager defaultManager] removeItemAtPath:self.m_destFile error:nil];
    }
}

/**
 *  关闭文件
 */
- (void)fileClose
{
    AudioFileDispose(m_srcFileRef1);
    AudioFileDispose(m_srcFileRef2);
    AudioFileDispose(m_destFileRef);
    
    if ([self.delegate respondsToSelector:@selector(audioMergeCloseDestFile:)])
    {
        [self.delegate audioMergeCloseDestFile:self];
    }
}

/**
 *  获取音频相关属性
 *
 *  @return YES / NO
 */
- (BOOL)fileGetProperty
{
    UInt32 size1 = sizeof(m_srcFormat1);
    UInt32 size2 = sizeof(m_srcFormat2);
    OSStatus err1 = ExtAudioFileGetProperty(m_srcFileRef1, kExtAudioFileProperty_FileDataFormat, &size1, &m_srcFormat1);
    OSStatus err2 = ExtAudioFileGetProperty(m_srcFileRef2, kExtAudioFileProperty_FileDataFormat, &size2, &m_srcFormat2);
    
    if (err1 != noErr
        || err2 != noErr)
    {
        return NO;
    }
    
    return YES;
}

/**
 *  更新文件的属性
 *
 *  @return YES / NO
 */
- (BOOL)updateFileProperty
{
    UInt32 dstSize = sizeof(self.m_destFormat);
    
    AudioStreamBasicDescription format = self.m_destFormat;
    OSStatus err1 = ExtAudioFileSetProperty(m_srcFileRef1, kExtAudioFileProperty_ClientDataFormat, dstSize, &format);
    OSStatus err2 = ExtAudioFileSetProperty(m_srcFileRef2, kExtAudioFileProperty_ClientDataFormat, dstSize, &format);
    OSStatus err3 = noErr;
    if (NULL != m_destFileRef)
    {
        err3 = ExtAudioFileSetProperty(m_destFileRef, kExtAudioFileProperty_ClientDataFormat, dstSize, &format);
    }

    if (err1 != noErr
        || err2 != noErr
        || err3 != noErr)
    {
        return NO;
    }
    
    return YES;
}

- (void)canConverter
{
#if 1
    AudioConverterRef audioConverter;
    UInt32 size = sizeof(audioConverter);
    
    if (NULL == m_destFileRef)
    {
        return;
    }
    
    ExtAudioFileGetProperty(m_destFileRef, kExtAudioFileProperty_AudioConverter, &size, &audioConverter);
    UInt32 canResume = 0;
    size = sizeof(canResume);
    OSStatus error = AudioConverterGetProperty(audioConverter, kAudioConverterPropertyCanResumeFromInterruption, &size, &canResume);
    if (noErr == error)
    {
        // we recieved a valid return value from the GetProperty call
        // if the property's value is 1, then the codec CAN resume work following an interruption
        // if the property's value is 0, then interruptions destroy the codec's state and we're done
        
        //        if (0 == canResume) canResumeFromInterruption = false;
        
        //        DMAMLog(@"Audio Converter %s continue after interruption!\n", (canResumeFromInterruption == 0 ? "CANNOT" : "CAN"));
    }
    else
    {
        // if the property is unimplemented (kAudioConverterErr_PropertyNotSupported, or paramErr returned in the case of PCM),
        // then the codec being used is not a hardware codec so we're not concerned about codec state
        // we are always going to be able to resume conversion after an interruption
        if (kAudioConverterErr_PropertyNotSupported == error)
        {
            DMAMLog(@"kAudioConverterPropertyCanResumeFromInterruption property not supported!\n");
        }
        else
        {
            DMAMLog(@"AudioConverterGetProperty kAudioConverterPropertyCanResumeFromInterruption result %ld\n", (long)error);
        }
    }
#endif
}

/**
 *  初始化BufList
 */
- (void)audioBufListInit
{
    m_srcBufList1.mNumberBuffers = 1;
    m_srcBufList1.mBuffers[0].mNumberChannels = self.m_destFormat.mChannelsPerFrame;
    m_srcBufList1.mBuffers[0].mDataByteSize = kBufferByteSize;
    m_srcBufList1.mBuffers[0].mData = m_srcBuffer1;
    
    m_srcBufList2.mNumberBuffers = 1;
    m_srcBufList2.mBuffers[0].mNumberChannels = self.m_destFormat.mChannelsPerFrame;
    m_srcBufList2.mBuffers[0].mDataByteSize = kBufferByteSize;
    m_srcBufList2.mBuffers[0].mData = m_srcBuffer2;
    
    m_destBufList.mNumberBuffers = 1;
    m_destBufList.mBuffers[0].mNumberChannels = self.m_destFormat.mChannelsPerFrame;
    m_destBufList.mBuffers[0].mDataByteSize = kBufferByteSize;
    m_destBufList.mBuffers[0].mData = m_destBuffer;
}

- (void)dataMerge
{
    short bytesPerChannel = self.m_destFormat.mBitsPerChannel / 8;
    for (int i=0; i<(kBufferByteSize/bytesPerChannel); i++)
    {
        long val1 = 0;
        long val2 = 0;
        long val3 = 0;
        
        //一定要先清0
        val1 = val2 = val3 = 0;
        val1 = [self memToValue:m_srcBuffer1 + i * bytesPerChannel bytes:bytesPerChannel];
        val2 = [self memToValue:m_srcBuffer2 + i * bytesPerChannel bytes:bytesPerChannel];
        
        val1 *= self.m_file1Volume;
        val2 *= self.m_file2Volume;
        
        val3 = val1 + val2;

        long min = [self minNumberWithBytes:bytesPerChannel];
        long max = [self maxNumberWithBytes:bytesPerChannel];
        if (val3 > max)
        {
            val3 = max;
        }
        else if (val3 < min)
        {
            val3 = min;
        }
        
        val3 *= self.m_destFileVolume;
        
        [self value:val3 toMem:m_destBuffer + i * bytesPerChannel bytes:bytesPerChannel];
    }
}

- (BOOL)writeBufToFile
{
    if ([self.delegate respondsToSelector:@selector(audioMergeWriteBuf:len:)])
    {
        long len = self.m_destFormat.mBytesPerFrame * m_numOfDestFrames;
        unsigned char *buf = (unsigned char *)m_destBuffer;
        
        return [self.delegate audioMergeWriteBuf:buf len:len];
    }
    
    if (noErr != ExtAudioFileWrite(m_destFileRef, m_numOfDestFrames, &m_destBufList))
    {
        return NO;
    }
    
    return YES;
}

- (void)deleteSrcFile
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    [manager removeItemAtPath:self.m_srcFile1 error:&error];
    if (nil != error)
    {
        DMAMLog(@"%@", error);
    }
    
    [manager removeItemAtPath:self.m_srcFile2 error:&error];
    if (nil != error)
    {
        DMAMLog(@"%@", error);
    }
}

- (void)stop
{
    self.cancel = YES;
}

- (void)start
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self fileMergeHandle];
    });
}

- (void)fileMergeFinishWithSuccess:(BOOL)isSuccess errorStr:(NSString *)errorStr
{
    if ([self.delegate respondsToSelector:@selector(audioMergeFinish:isSuccess:error:)])
    {
        NSError *error = nil;
        if (errorStr.length > 0)
        {
            error = [NSError errorWithDomain:nil
                                        code:-1
                                    userInfo:@{NSLocalizedDescriptionKey:errorStr}];
        }
        
        [self.delegate audioMergeFinish:self isSuccess:isSuccess error:error];
    }
}

- (void)fileMergeHandle
{
    DMAMLog(@"merge begin : %@", [NSDate date]);
    
    self.cancel = NO;
    
    BOOL isSuccess = NO;

    //open file
    if (![self srcFileOpen])
    {
        [self fileClose];
        [self deleteDestFile];
        
        [self fileMergeFinishWithSuccess:isSuccess errorStr:@"open file failed!"];
        
        return;
    }
    
    //get property
    if (![self fileGetProperty])
    {
        [self fileClose];
        [self deleteDestFile];
        
        [self fileMergeFinishWithSuccess:isSuccess errorStr:@"get file property failed!"];
        
        return;
    }
    
    //create dest file
    if (![self destFileCreate])
    {
        [self fileClose];
        [self deleteDestFile];
        
        [self fileMergeFinishWithSuccess:isSuccess errorStr:@"create dest file failed!"];
        return;
    }
    
    //update property
    if (![self updateFileProperty])
    {
        [self fileClose];
        [self deleteDestFile];
        
        [self fileMergeFinishWithSuccess:isSuccess errorStr:@"update file property failed!"];
        return;
    }
    
    //can converter
    [self canConverter];
    
    //buf list init
    [self audioBufListInit];
    
    if (self.m_destFormat.mBytesPerFrame > 0)
    {
        m_numOfSrcFrames1 = m_numOfSrcFrames2 = (kBufferByteSize / self.m_destFormat.mBytesPerFrame);
    }
    
    OSStatus readErr1 = noErr;
    OSStatus readErr2 = noErr;
    
    isSuccess = YES;
    while (1)
    {
        if (self.isCancel)
        {
            isSuccess = NO;
            [self fileMergeFinishWithSuccess:isSuccess errorStr:@"user cancel"];
            
            break;
        }
        
        //必须先清空!!!!!
        memset(m_srcBuffer1, 0, sizeof(m_srcBuffer1));
        memset(m_srcBuffer2, 0, sizeof(m_srcBuffer2));
        memset(m_srcBuffer2, 0, sizeof(m_destBuffer));
        
        readErr1 = ExtAudioFileRead(m_srcFileRef1, &m_numOfSrcFrames1, &m_srcBufList1);
        readErr2 = ExtAudioFileRead(m_srcFileRef2, &m_numOfSrcFrames2, &m_srcBufList2);
        
        if (readErr1 != noErr
            || readErr2 != noErr)
        {
            isSuccess = NO;
            [self fileMergeFinishWithSuccess:isSuccess errorStr:@"read src file failed"];
            
            break;
        }
        
        if (m_numOfSrcFrames1 <= 0
            || m_numOfSrcFrames2 <= 0)
        {
            break;
        }
        
        m_numOfDestFrames = (m_numOfSrcFrames1 < m_numOfSrcFrames2) ? m_numOfSrcFrames1 : m_numOfSrcFrames2;
        
        //data merge
        [self dataMerge];
        
        if (![self writeBufToFile])
        {
            isSuccess = NO;
            
            [self fileMergeFinishWithSuccess:isSuccess errorStr:@"write dest file failed"];
            
            break;
        } // if
    } // while
    
    // close
    [self fileClose];
    
    if (isSuccess)
    {
        // merge 成功
        [self fileMergeFinishWithSuccess:YES errorStr:nil];
    }
    else
    { //failed, delete dest file
        [self deleteDestFile];
    }
    
    DMAMLog(@"merge:%@", isSuccess ? @"YES" : @"NO");
    
    DMAMLog(@"merge end : %@", [NSDate date]);
}

- (int)minNumberWithBytes:(short)bytes
{
    int val = 0;
    
    switch (bytes)
    {
        case 1:
            val = -128;
            break;
        case 2:
            val = -32768;
            break;
        case 3:
            val = -8388608;
            break;
        default:
            break;
    }
    
    return val;
}

- (int)maxNumberWithBytes:(short)bytes
{
    int val = 0;
    
    switch (bytes)
    {
        case 1:
            val = 127;
            break;
        case 2:
            val = 32767;
            break;
        case 3:
            val = 8388607;
            break;
        default:
            break;
    }
    
    return val;
}

- (long)memToValue:(void *)p bytes:(int)bytes
{
    UInt8 *pmem = p;
    if (1 == bytes)
    {
        return (char)((UInt8)pmem[0]);
    }
    else if (2 == bytes)
    {
        return (short)((UInt8)pmem[0] | (((UInt8)pmem[1]) << 8));
    }
    else if (3 == bytes)
    {
        return (int)((UInt8)pmem[0] | (((UInt8)pmem[1]) << 8) | (((UInt8)pmem[2]) << 16));
    }
    else if (4 == bytes)
    {
        return (long)((UInt8)pmem[0] | (((UInt8)pmem[1]) << 8) | (((UInt8)pmem[2]) << 16) | (((UInt8)pmem[3]) << 24));
    }
    
    return 0;
}

- (void)value:(long)value toMem:(void *)p bytes:(int)bytes
{
    UInt8 *pmem = p;
    UInt8 temp = 0;
    
    if (1 == bytes)
    {
        temp = (UInt8)value;
        pmem[0] = temp;
    }
    else if (2 == bytes)
    {
        temp = value & 0xff;
        pmem[0] = temp;
        temp = (value & 0xff00) >> 8;
        pmem[1] = temp;
    }
    else if (3 == bytes)
    {
        temp = value & 0xff;
        pmem[0] = temp;
        temp = (value & 0xff00) >> 8;
        pmem[1] = temp;
        temp = (value & 0xff0000) >> 16;
        pmem[2] = temp;
    }
    else if (4 == bytes)
    {
        temp = value & 0xff;
        pmem[0] = temp;
        temp = (value & 0xff00) >> 8;
        pmem[1] = temp;
        temp = (value & 0xff0000) >> 16;
        pmem[2] = temp;
        temp = (value & 0xff000000) >> 24;
        pmem[3] = temp;
    }
}

- (void)parameterInit
{
    [self setDefaultFormat];
}

- (float)checkVoume:(float)volume
{
    if (volume > 1.0)
    {
        volume = 1.0;
    }
    
    if (volume < 0.00001)
    {
        volume = 0.00001;
    }
    
    return volume;
}

- (void)setM_file1Volume:(float)m_file1Volume
{
    m_file1Volume = [self checkVoume:m_file1Volume];
    
    _m_file1Volume = m_file1Volume;
}

- (void)setM_file2Volume:(float)m_file2Volume
{
    m_file2Volume = [self checkVoume:m_file2Volume];
    
    _m_file2Volume = m_file2Volume;
}

- (void)setM_destFileVolume:(float)m_destFileVolume
{
    m_destFileVolume = [self checkVoume:m_destFileVolume];
    
    _m_destFileVolume = m_destFileVolume;
}

- (void)setDefaultFormat
{
    AudioStreamBasicDescription format={0};
    
    format.mSampleRate = kSampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mFramesPerPacket = 1;
    format.mChannelsPerFrame = kNumberOfChannel;
    format.mBitsPerChannel = kBitsPerSample;
    format.mBytesPerFrame = format.mBitsPerChannel / 8 * format.mChannelsPerFrame;
    format.mBytesPerPacket = format.mBytesPerFrame;
    
    self.m_destFormat = format;
}


@end
