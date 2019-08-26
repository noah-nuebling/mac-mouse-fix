//
//  ProgressDelegate.m
//  ObjectiveCExample
//
//  Created by Antoine Cœur on 04/10/2017.
//

#import "ProgressDelegate.h"

@implementation ProgressDelegate

- (instancetype)init
{
    self = super.init;
    progressEvents = [NSMutableArray array];
    return self;
}

- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo {
    NSLog(@"*** zipArchiveWillUnzipArchiveAtPath: `%@` zipInfo:", path);
}

- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath {
    NSLog(@"*** zipArchiveDidUnzipArchiveAtPath: `%@` zipInfo: unzippedPath: `%@`", path, unzippedPath);
}

- (BOOL)zipArchiveShouldUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo
{
    NSLog(@"*** zipArchiveShouldUnzipFileAtIndex: `%d` totalFiles: `%d` archivePath: `%@` fileInfo:", (int)fileIndex, (int)totalFiles, archivePath);
    return YES;
}

- (void)zipArchiveWillUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo {
    NSLog(@"*** zipArchiveWillUnzipFileAtIndex: `%d` totalFiles: `%d` archivePath: `%@` fileInfo:", (int)fileIndex, (int)totalFiles, archivePath);
}

- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo {
    NSLog(@"*** zipArchiveDidUnzipFileAtIndex: `%d` totalFiles: `%d` archivePath: `%@` fileInfo:", (int)fileIndex, (int)totalFiles, archivePath);
}

- (void)zipArchiveProgressEvent:(unsigned long long)loaded total:(unsigned long long)total {
    NSLog(@"*** zipArchiveProgressEvent: loaded: `%llu` total: `%llu`", loaded, total);
    [progressEvents addObject:@(loaded)];
}

@end
