//
//  ViewController.m
//  DMAudioMergeDemo
//
//  Created by Dream on 15/6/21.
//  Copyright (c) 2015年 GoSing. All rights reserved.
//

#import "ViewController.h"
#import "DMAudioMergeManager.h"

@interface ViewController () <DMAudioMergeManagerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"%@", NSTemporaryDirectory());
    
    NSString *destFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"destFile.mp3"];
    
    NSString *srcFile1 = [[NSBundle mainBundle] pathForResource:@"孙楠-只要有你" ofType:@"mp3"];
    NSString *srcFile2 = [[NSBundle mainBundle] pathForResource:@"许巍-第三极(央视纪录片《第三极》主题曲)" ofType:@"mp3"];
    
    DMAudioMergeManager *mergeManager = [DMAudioMergeManager sharedInstance];
    mergeManager.delegate = self;
    [mergeManager addAudioMergeWithDestFile:destFile destFileVolume:1.0 srcFile1:srcFile1 srcFile1Volume:1.0 srcFile2:srcFile2 srcFile2Volume:1.0];
}


#pragma mark - DMAudioMergeManagerDelegate
- (void)audioMergeManager:(DMAudioMergeManager *)manager didMergeFinish:(DMAudioMerge *)merge isSuccess:(BOOL)isSuccess error:(NSError *)error
{
    NSLog(@"%s, isSuccess = %d", __func__, isSuccess);
}

@end
