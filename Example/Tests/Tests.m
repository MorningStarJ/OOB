//
//  OOBTests.m
//  OOBTests
//
//  Created by lifei on 03/08/2019.
//  Copyright (c) 2019 lifei. All rights reserved.
//

@import XCTest;
#import "OOB.h"
#import "OOBTemplateUtils.h"
#import <objc/message.h>

@interface Tests : XCTestCase

@property (nonatomic, strong) UIImage *targetImage; // 目标图像
@property (nonatomic, strong) UIViewController *topVC; // 导航控制器的顶VC
@property (nonatomic, strong) AVAssetReader *assetReader; // 读取视频CMSampleBufferRef

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    self.targetImage = [UIImage imageNamed:@"apple"];
    // 找到顶视图 VC
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    self.topVC = rootViewController;
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)rootViewController;
        self.topVC = nav.topViewController;
    }
}

- (void)tearDown
{
    [OOBTemplate stop];
    [self.assetReader cancelReading];
    self.assetReader = nil;
    self.targetImage = nil;
    [super tearDown];
}

- (void)testInitialize{
    XCTAssertNotNil(self.targetImage, @"待识别图像不为空");
    XCTAssertNotNil(self.topVC, @"当前控制器不为空");
    XCTAssertNil(OOBTemplate.preview, @"预览图层默认为空");
    XCTAssertNil(OOBTemplate.targetImg, @"目标图像默认为空");
    XCTAssertNotNil(OOBTemplate.cameraSessionPreset, @"视频尺寸不为空");
    XCTAssertTrue(OOBTemplate.cameraType == OOBCameraTypeBack, @"默认为后置摄像头");
    XCTAssertTrue(OOBTemplate.similarValue <= 1.0f, @"相似度阈值小于等于1");
    UIImage *markImg = [OOBTemplate createRect:_targetImage.size borderColor:[UIColor redColor] borderWidth:3 cornerRadius:5];
    XCTAssertNotNil(markImg, @"生产矩形标记视图");
}

///MARK: - TEST IMAGE
- (void)testImageDefaultSet {
    UIImage *bgImg = [UIImage imageNamed:@"screen_shot"];
    XCTAssertNotNil(bgImg, @"背景图像不为空");
    XCTAssertNotNil(self.targetImage, @"待识别图像不为空");
    [self imageMatchTest:bgImg];
}

- (void)testImageUserSet {
    UIImage *bgImg = [UIImage imageNamed:@"screen_shot"];
    XCTAssertNotNil(bgImg, @"背景图像不为空");
    XCTAssertNotNil(self.targetImage, @"待识别图像不为空");
    // 测试设置预览图层
    OOBTemplate.preview = self.topVC.view;
    [self imageMatchTest:bgImg];
    // 测试设置相似度
    OOBTemplate.similarValue = 0.9;
    [self imageMatchTest:bgImg];
    // 测试设置两者
    OOBTemplate.similarValue = 0.8;
    OOBTemplate.preview = self.topVC.view;
    [self imageMatchTest:bgImg];
    // 图片测试时，设置摄像头不支持
    OOBTemplate.cameraType = OOBCameraTypeBack;
    OOBTemplate.cameraSessionPreset = AVCaptureSessionPresetMedium;
}

- (void)testImageExpSimilarValueOverflow {
    UIImage *bgImg = [UIImage imageNamed:@"screen_shot"];
    XCTAssertNotNil(bgImg, @"背景图像不为空");
    OOBTemplate.similarValue = 0.8;
    [self imageMatchTest:bgImg];
}

- (void)testImageExpBigTgImg {
    UIImage *bgImg = [UIImage imageNamed:@"screen_shot"];
    XCTAssertNotNil(bgImg, @"背景图像不为空");
    [OOBTemplate match:bgImg bgImg:bgImg result:^(CGRect rect, CGFloat similar) {
        XCTAssertTrue(similar > 0, @"相似度在 0 到 1 之间。");
    }];
}

- (void)testImageExpImgNil {
    UIImage *bgImg = [UIImage imageNamed:@"screen_shot"];
    XCTAssertNotNil(bgImg, @"背景图像不为空");
    XCTAssertNotNil(self.targetImage, @"待识别图像不为空");
    // 测试目标图片为空
    UIImage *noImg = nil;
    [OOBTemplate match:noImg bgImg:bgImg result:^(CGRect rect, CGFloat similar) {
        XCTAssertTrue(similar == 0, @"图片为空，相似度为 0。");
        XCTAssertTrue(CGRectEqualToRect(rect, CGRectZero), @"图片为空，Frame 为空");
    }];
    
    // 测试背景图片为空
    UIImage *noBgImg = nil;
    [OOBTemplate match:self.targetImage bgImg:noBgImg result:^(CGRect rect, CGFloat similar) {
        XCTAssertTrue(similar == 0, @"图片为空，相似度为 0。");
        XCTAssertTrue(CGRectEqualToRect(rect, CGRectZero), @"图片为空，Frame 为空");
    }];
    
    // 测试二者都是 nil
    [OOBTemplate match:noImg bgImg:noBgImg result:^(CGRect rect, CGFloat similar) {
        XCTAssertTrue(similar == 0, @"图片为空，相似度为 0。");
        XCTAssertTrue(CGRectEqualToRect(rect, CGRectZero), @"图片为空，Frame 为空");
    }];
}

- (void)imageMatchTest:(UIImage *)bgImg{
    // 阈值超限，设为默认值 0.7
    OOBTemplate.similarValue = 1.8;
    [OOBTemplate match:self.targetImage bgImg:bgImg result:^(CGRect rect, CGFloat similar) {
        XCTAssertTrue(similar > 0.5, @"相似度在 0 到 1 之间。");
        XCTAssertTrue(rect.size.width > 0, @"目标宽度大于 0。");
        XCTAssertTrue(rect.size.height > 0, @"目标高度大于 0。");
    }];
}

///MARK: - TEST VIDEO
- (void)testVideoDefaultSet {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"oob_apple.m4v" withExtension:nil];
    XCTAssertNotNil(url, @"待测视频不能为空");
    [self videoOutputTest:url];
}

- (void)testVideoUserSet {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"oob_apple.m4v" withExtension:nil];
    XCTAssertNotNil(url, @"待测视频不能为空");
    OOBTemplate.preview = self.topVC.view;
    OOBTemplate.similarValue = 0.9;
    [self videoOutputTest:url];
    // 更换相似度
    OOBTemplate.similarValue = 0.8;
    // 更换目标
    OOBTemplate.targetImg = [UIImage imageNamed:@"caomeicui"];
    // 视频测试时，设置摄像头不支持
    OOBTemplate.cameraType = OOBCameraTypeBack;
    OOBTemplate.cameraSessionPreset = AVCaptureSessionPresetMedium;
}

- (void)testVideoExpUrlNil {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"nnnnnnn.m4v" withExtension:nil];
    XCTAssertNil(url, @"测试视频为空");
    //测试异步视频流
    XCTestExpectation *expVideoNil = [self expectationWithDescription:@"Can't read video sampleBuffer."];
    // 测试视频流
    [OOBTemplate match:self.targetImage videoURL:url result:^(CGRect rect, CGFloat similar, UIImage * _Nullable frame) {
        XCTAssertTrue(CGRectIsEmpty(rect), @"目标图像为空，目标 CGRectZero。");
        XCTAssertTrue(similar == 0, @"目标图像为空，相似度为 0。");
        XCTAssertNil(frame, @"获取视频帧为空");
        [expVideoNil fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"expVideoNil=%@",error);
        }
    }];
}

- (void)testVideoExpBgViewNil {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"oob_apple.m4v" withExtension:nil];
    XCTAssertNotNil(url, @"待测视频不能为空");
    OOBTemplate.preview = nil;
    [self videoOutputTest:url];
}

- (void)testVideoExpTgImgNil {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"oob_apple.m4v" withExtension:nil];
    XCTAssertNotNil(url, @"待测视频不能为空");
    UIImage *tgImgNil = nil;
    //测试异步视频流
    XCTestExpectation *expVideoTgImgNil = [self expectationWithDescription:@"Can't read video sampleBuffer."];
    // 测试视频流
    [OOBTemplate match:tgImgNil videoURL:url result:^(CGRect rect, CGFloat similar, UIImage * _Nullable frame) {
        XCTAssertTrue(CGRectIsEmpty(rect), @"目标图像为空，目标 CGRectZero。");
        XCTAssertTrue(similar == 0, @"目标图像为空，相似度为 0。");
        XCTAssertNil(frame, @"获取视频帧为空");
        [expVideoTgImgNil fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"expVideoTgImgNil=%@",error);
        }
    }];
}

- (void)testVideoExpSimilarValueOverflow {
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"oob_apple.m4v" withExtension:nil];
    XCTAssertNotNil(url, @"待测视频不能为空");
    // 设置相似度超限
    OOBTemplate.similarValue = 1.9;
    XCTAssertTrue(OOBTemplate.similarValue == 0.7, @"超限默认为 0.7");
    [self videoOutputTest:url];
}

- (void)videoOutputTest:(NSURL *)url{
    //测试异步视频流
    XCTestExpectation *expVideoOutput = [self expectationWithDescription:@"Can't read video sampleBuffer."];
    // 测试视频流
    [OOBTemplate match:self.targetImage videoURL:url result:^(CGRect rect, CGFloat similar, UIImage * _Nullable frame) {
        XCTAssertTrue(similar >= 0, @"相似度在 0 到 1 之间。");
        XCTAssertTrue(similar <= 1, @"相似度在 0 到 1 之间。");
        XCTAssertTrue(rect.size.width >= 0, @"目标宽度大于等于 0。");
        XCTAssertTrue(rect.size.height >= 0, @"目标高度大于等于 0。");
        XCTAssertNotNil(frame, @"获取视频帧不为空");
        [expVideoOutput fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"expVideoOutput=%@",error);
        }
    }];
}

///MARK: - TEST CAMERA
- (void)testCameraDefaultSet{
    // 测试视频流
    [self captureOutputTest:self.targetImage];
}

// 测试相机用户自定义设置
- (void)testCameraUserSet
{
    UIViewController *targetVC = [[UIViewController alloc]init];
    targetVC.view.backgroundColor = [UIColor whiteColor];
    [self.topVC presentViewController:targetVC animated:NO completion:nil];
    
    // 设置预览图层
    OOBTemplate.preview = targetVC.view;
    XCTAssertEqual(OOBTemplate.preview, targetVC.view, @"设置预览图层");
    
    // 更换目标视图
    UIImage *bbImg = [UIImage imageNamed:@"caomeicui"];
    OOBTemplate.targetImg = bbImg;
    XCTAssertNotEqual(OOBTemplate.targetImg, bbImg, @"设置目标图像去Alpha");
    
    // 切换摄像头
    OOBTemplate.cameraType = OOBCameraTypeFront;
    XCTAssertTrue(OOBTemplate.cameraType == OOBCameraTypeFront, @"设置前置摄像头");
    
    // 设置不支持的视频格式
    OOBTemplate.cameraSessionPreset = @"不支持的视频格式";
    // 设置摄像头预览质量
    OOBTemplate.cameraSessionPreset = AVCaptureSessionPresetLow;
    XCTAssertTrue([OOBTemplate.cameraSessionPreset isEqualToString:AVCaptureSessionPresetLow], @"设置图像质量");
    
    OOBTemplate.similarValue = 0.9;
    XCTAssertEqual(OOBTemplate.similarValue, 0.9, @"图像对比相似度");
    // 测试视频流
    [self captureOutputTest:bbImg];
    
    // 切换摄像头
    OOBTemplate.cameraType = OOBCameraTypeBack;
    XCTAssertTrue(OOBTemplate.cameraType == OOBCameraTypeBack, @"设置后置置摄像头");
}

- (void)testCameraExpBgViewNil {
    // 设置预览图层为空
    OOBTemplate.preview = nil;
    // 测试视频流
    [self captureOutputTest:self.targetImage];
}

- (void)testCameraExpTgImgNil {
    // 测试目标为空
    UIImage *tImg = nil;
    [self captureOutputTest:tImg];
}

- (void)testCameraExpChangeTgImg {
    // 测试视频流
    [self captureOutputTest:self.targetImage];
    // 更换目标视图为空
    UIImage *tImg = [UIImage imageNamed:@"caomeicui"];
    OOBTemplate.targetImg = tImg;
}

- (void)testCameraExpChangeTgImgNil {
    // 测试视频流
    [self captureOutputTest:self.targetImage];
    // 更换目标视图为空
    UIImage *tImg = [UIImage imageNamed:@"1235666"];
    OOBTemplate.targetImg = tImg;
    XCTAssertNil(OOBTemplate.targetImg, @"目标图像为空");
}

- (void)testCameraExpSimilarValueOverflow {
    // 设置相似度超限
    OOBTemplate.similarValue = 1.9;
    XCTAssertTrue(OOBTemplate.similarValue == 0.7, @"超限默认为 0.7");
    // 测试视频流
    [self captureOutputTest:self.targetImage];
}

-(void)captureOutputTest:(UIImage *)tgImg{
    // 如果是真机
    if (TARGET_OS_SIMULATOR != 1) {
        // 设置变量后测试
        NSDate *beginDate1 = [NSDate date];
        XCTestExpectation *expectation1 = [self expectationWithDescription:@"Camer should not open."];
        [OOBTemplate match:tgImg result:^(CGRect rect, CGFloat similar) {
            XCTAssertTrue(similar >= 0, @"相似度在 0 到 1 之间。");
            XCTAssertTrue(similar <= 1, @"相似度在 0 到 1 之间。");
            NSTimeInterval timeDiff = [[NSDate date] timeIntervalSinceDate:beginDate1];
            if (timeDiff > 2.0) {
                [expectation1 fulfill];
            }
        }];
        [self waitForExpectationsWithTimeout:5.0 handler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"expectation1=%@",error);
            }
        }];
        // 回到主页
        UIViewController *presentedVC = self.topVC.presentedViewController;
        [presentedVC dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    
    // 如果是模拟器
    NSNumber *yuvNum = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    AVAssetReaderTrackOutput *trackOutput = [self createTrackOutput:yuvNum];
    // 开始读取 CMSampleBufferRef
    [self.assetReader startReading];
    // 定义回调 block
    [OOBTemplate match:tgImg result:^(CGRect rect, CGFloat similar) {
        XCTAssertTrue(similar >= 0, @"相似度在 0 到 1 之间。");
        XCTAssertTrue(similar <= 1, @"相似度在 0 到 1 之间。");
        XCTAssertTrue(rect.size.width >= 0, @"目标宽度大于等于 0。");
        XCTAssertTrue(rect.size.height >= 0, @"目标高度大于等于 0。");
    }];
    
    CMSampleBufferRef samBufRef = [trackOutput copyNextSampleBuffer];
    // 执行
    OOBTemplate *sharedOOB = [[OOBTemplate alloc] init];
    OOBTemplate *copyedOOB = sharedOOB.copy;
    XCTAssertEqual(sharedOOB, copyedOOB, @"OOBTemplate 为单例对象");
    SEL delegateSel = NSSelectorFromString(@"captureOutput:didOutputSampleBuffer:fromConnection:");
    ((void (*) (id, SEL, AVCaptureOutput *, CMSampleBufferRef, AVCaptureConnection *)) objc_msgSend) (sharedOOB, delegateSel, nil, samBufRef, nil);
    // 回到主页
    UIViewController *presentedVC = self.topVC.presentedViewController;
    [presentedVC dismissViewControllerAnimated:NO completion:nil];
    // 释放 CMSampleBufferRef
    if (samBufRef) {
        CMSampleBufferInvalidate(samBufRef);
        CFRelease(samBufRef);
    }
}

///MARK: - TEST HELPER
- (void)testUtilsSamBufFormat {
    // 测试视频格式
    NSNumber *bgrNum = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    AVAssetReaderTrackOutput *trackOutput = [self createTrackOutput:bgrNum];
    // 开始读取 CMSampleBufferRef
    [self.assetReader startReading];
    CMSampleBufferRef samBufRef = [trackOutput copyNextSampleBuffer];
    NSDictionary *locDict = [OOBTemplateUtils locInVideo:samBufRef TemplateImg:self.targetImage SimilarValue:0.8];
    XCTAssertNil(locDict, @"Only YUV is supported");
    // 释放 CMSampleBufferRef
    if (samBufRef) {
        CMSampleBufferInvalidate(samBufRef);
        CFRelease(samBufRef);
    }
}

- (void)testUtilsSamBufNil {
    // 测试 Buffer 为 NULL
    CMSampleBufferRef samBufRefNull = NULL;
    NSDictionary *bufNullDict = [OOBTemplateUtils locInVideo:samBufRefNull TemplateImg:self.targetImage SimilarValue:0.8];
    XCTAssertNil(bufNullDict, @"Target image can't be nil.");
    // 测试目标图像为空
    NSNumber *yuvNum = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    AVAssetReaderTrackOutput *trackOutput = [self createTrackOutput:yuvNum];
    // 开始读取 CMSampleBufferRef
    [self.assetReader startReading];
    CMSampleBufferRef samBufRef = [trackOutput copyNextSampleBuffer];
    UIImage *tgImg = nil;
    NSDictionary *tgNilDict = [OOBTemplateUtils locInVideo:samBufRef TemplateImg:tgImg SimilarValue:0.8];
    XCTAssertNil(tgNilDict, @"Target image can't be nil.");
    // 释放 CMSampleBufferRef
    if (samBufRef) {
        CMSampleBufferInvalidate(samBufRef);
        CFRelease(samBufRef);
    }
}

- (AVAssetReaderTrackOutput *)createTrackOutput:(NSNumber *)formatNum{
    // 如果是模拟器
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"oob_apple.m4v" withExtension:nil];
    XCTAssertNotNil(url, @"待测视频不能为空");
    // 获取视频CMSampleBufferRef
    AVAsset *asset = [AVAsset assetWithURL:url];
    // 1. 配置AVAssetReader
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    self.assetReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
    // 设置输出格式kCVPixelBufferWidthKey kCVPixelBufferHeightKey
    NSDictionary *readerOutputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:formatNum, kCVPixelBufferPixelFormatTypeKey,nil];
    
    AVAssetReaderTrackOutput *trackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:readerOutputSettings];
    [self.assetReader addOutput:trackOutput];
    return trackOutput;
}

@end


