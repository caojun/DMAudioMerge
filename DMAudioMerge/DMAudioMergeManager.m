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

#import "DMAudioMergeManager.h"
#import "DMAudioMerge.h"

#if DEBUG
#   define DMAMMLog(...)  NSLog(__VA_ARGS__)
#else
#   define DMAMMLog(...)
#endif

@interface DMAudioMergeManager () <DMAudioMergeDelegate>

@property (nonatomic, strong) NSMutableArray *m_mergeQueue;

@end

@implementation DMAudioMergeManager

#pragma mark - Life Cycle

+ (instancetype)sharedInstance
{
    static DMAudioMergeManager *audioMergeManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        audioMergeManager = [[self alloc] init];
        [audioMergeManager defaultSetting];
    });
    
    return audioMergeManager;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static DMAudioMergeManager *allocZone = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allocZone = [super allocWithZone:zone];
    });
    
    return allocZone;
}

- (void)defaultSetting
{
    
}

- (int)audioMergeTag
{
    static int audioMergeTagValue = 0;
    
    if (0 == audioMergeTagValue)
    {
        audioMergeTagValue = arc4random() % 100000;
    }
    else
    {
        audioMergeTagValue++;
    }
    
    return audioMergeTagValue;
}

- (int)addAudioMergeWithDestFile:(NSString *)destFile
                   destFileVolume:(float)destFileVolume
                         srcFile1:(NSString *)file1
                   srcFile1Volume:(float)file1Volume
                         srcFile2:(NSString *)file2
                   srcFile2Volume:(float)file2Volume
{
    int ID = -1;
    DMAudioMerge *merge = [DMAudioMerge audioMergeDestFile:destFile destFileVolume:destFileVolume srcFile1:file1 srcFile1Volume:file1Volume srcFile2:file2 srcFile2Volume:file2Volume];
    if (nil != merge)
    {
        [self.m_mergeQueue addObject:merge];
        
        ID = [self audioMergeTag];
        
        merge.tag = ID;
        merge.delegate = self;
        [merge start];
    }
    
    return ID;
}

/**
 *  停止某一个
 *
 *  @param ID 由addAudioMergeWithDestFile返回的ID
 */
- (void)stopWithID:(int)ID
{
    for (DMAudioMerge *merge in self.m_mergeQueue)
    {
        if (merge.tag == ID)
        {
            [merge stop];
            break;
        }
    }
}

- (void)stopAll
{
    for (DMAudioMerge *merge in self.m_mergeQueue)
    {
        [merge stop];
    }
    
    [self.m_mergeQueue removeAllObjects];
}

#pragma mark - DMAudioMergeDelegate
- (void)audioMergeFinish:(DMAudioMerge *)merge isSuccess:(BOOL)isSuccess error:(NSError *)error
{
    DMAMMLog(@"%@, error = %@", isSuccess ? @"success" : @"failed", error);
    
    if ([self.delegate respondsToSelector:@selector(audioMergeManager:didMergeFinish:isSuccess:error:)])
    {
        [self.delegate audioMergeManager:self didMergeFinish:merge isSuccess:isSuccess error:error];
    }
    
    if (isSuccess)
    {
        [merge deleteSrcFile];
    }
    
    [self.m_mergeQueue removeObject:merge];
}

#pragma mark - setter / getter
- (NSMutableArray *)m_mergeQueue
{
    if (nil == _m_mergeQueue)
    {
        _m_mergeQueue = [NSMutableArray array];
    }
    
    return _m_mergeQueue;
}

@end
