//
//  SSZipArchiveTests.m
//  SSZipArchiveTests
//
//  Created by Sam Soffes on 10/3/11.
//  Copyright (c) 2011-2014 Sam Soffes. All rights reserved.
//

#import <SSZipArchive/SSZipArchive.h>
#import <XCTest/XCTest.h>
#import <CommonCrypto/CommonDigest.h>

#import "CollectingDelegate.h"
#import "CancelDelegate.h"
#import "ProgressDelegate.h"

@interface SSZipArchiveTests : XCTestCase
@end

@interface NSString (SSZipArchive)
- (NSString *)_sanitizedPath;
@end

@implementation SSZipArchiveTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
    [[NSFileManager defaultManager] removeItemAtPath:[self _cachesPath:nil] error:nil];
}


- (void)testZipping {
    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];

    NSString *outputPath = [self _cachesPath:@"Zipped"];

    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];
    
    XCTAssertTrue(success, @"create zip failure");
    // TODO: Make sure the files are actually zipped. They are, but the test should be better.
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    BOOL protected = [SSZipArchive isFilePasswordProtectedAtPath:archivePath];
    XCTAssertFalse(protected, @"has no password");
}


- (void)testZippingWithPassword {
    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];
    
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths withPassword:@"dolphins🐋"];
    
    XCTAssertTrue(success, @"create zip failure");
    // TODO: Make sure the files are actually zipped. They are, but the test should be better.
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    BOOL protected = [SSZipArchive isFilePasswordProtectedAtPath:archivePath];
    XCTAssertTrue(protected, @"has password");
}


- (void)testZippingWithZeroLengthPassword {
    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];
    
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths withPassword:@""];
    
    XCTAssertTrue(success, @"create zip failure");
    // TODO: Make sure the files are actually zipped. They are, but the test should be better.
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    BOOL protected = [SSZipArchive isFilePasswordProtectedAtPath:archivePath];
    XCTAssertTrue(protected, @"has password");
}


- (void)testDirectoryZipping {
    // use Unicode as folder (has a file in root and a file in subfolder)
    [self testUnzippingWithUnicodeFilenameInside];
    NSString *inputPath = [self _cachesPath:@"Unicode"];

    NSString *outputPath = [self _cachesPath:@"FolderZipped"];
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"ArchiveWithFolders.zip"];

    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withContentsOfDirectory:inputPath];
    XCTAssertTrue(success, @"create zip failure");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Folder Archive created");
}

- (void)testMultipleZippping{
    NSArray *inputPaths = @[[[NSBundle bundleForClass: [self class]]pathForResource:@"0" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"1" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"2" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"3" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"4" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"5" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"6" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"7" ofType:@"m4a"]
                            ];
    NSString *outputPath = [self _cachesPath:@"Zipped"];

    // this is a monster
    // if testing on iOS, within 30 loops it will fail; however, on OS X, it may take about 900 loops
    for (int test = 0; test < 20; test++)
    {
        // Zipping
        NSString *archivePath = [outputPath stringByAppendingPathComponent:[NSString stringWithFormat:@"queue_test_%d.zip", test]];

        BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];
        XCTAssertTrue(success, @"create zip failure");
        
        long long threshold = 510000; // 510kB:size slightly smaller than a successful zip, but much larger than a failed one
        long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:archivePath error:nil][NSFileSize] longLongValue];
        XCTAssertTrue(fileSize > threshold, @"zipping failed at %@!", archivePath);
    }
}

- (void)testUnzipping {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Regular"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}

- (void)testSmallFileUnzipping {
    NSString *zipPath = [[NSBundle bundleForClass: [self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Regular"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}

- (void)testUnzippingProgress {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Progress"];

    ProgressDelegate *delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    // 4 events: the first, then for each of the two files one, then the final event
    XCTAssertTrue(4 == [delegate->progressEvents count], @"Expected 4 progress events");
    XCTAssertTrue(0 == [delegate->progressEvents[0] intValue]);
    XCTAssertTrue(619 == [delegate->progressEvents[1] intValue]);
    XCTAssertTrue(1114 == [delegate->progressEvents[2] intValue]);
    XCTAssertTrue(1436 == [delegate->progressEvents[3] intValue]);
}


- (void)testUnzippingWithPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];

    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:@"passw0rd" error:&error delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}

- (void)testUnzippingWithAESPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestAESPasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];
    
    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:@"passw0rd" error:&error delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"README.md"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");
    
    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE.txt"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}

- (void)testUnzippingWithInvalidPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];
    
    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:@"passw0rd123" error:&error delegate:delegate];
    XCTAssertFalse(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertFalse([fileManager fileExistsAtPath:testPath], @"Readme not unzipped");
    
    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertFalse([fileManager fileExistsAtPath:testPath], @"LICENSE not unzipped");
}


- (void)testIsPasswordInvalidForArchiveAtPath {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    
    NSError *error = nil;
    
    BOOL fileHasValidPassword = [SSZipArchive isPasswordValidForArchiveAtPath:zipPath password:@"passw0rd" error:&error];
    
    XCTAssertTrue(fileHasValidPassword, @"Valid password reports false.");
    
    BOOL fileHasInvalidValidPassword = [SSZipArchive isPasswordValidForArchiveAtPath:zipPath password:@"passw0rd123" error:&error];
    
    XCTAssertFalse(fileHasInvalidValidPassword, @"Invalid password reports true.");
}

- (void)testIsFilePasswordProtectedAtPath {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    
    BOOL protected = [SSZipArchive isFilePasswordProtectedAtPath:zipPath];
    XCTAssertFalse(protected, @"has no password");
    
    
    NSString *zipWithPasswordPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    
    protected = [SSZipArchive isFilePasswordProtectedAtPath:zipWithPasswordPath];
    XCTAssertTrue(protected, @"has password");
}

- (void)testZippingAndUnzippingWithUnicodePassword {
    
    /********** Zipping ********/
    
    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];
    
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedUnicodePasswordArchive.zip"];
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths withPassword:@"ꊐ⌒Ⅳ🤐"];
    
    XCTAssertTrue(success, @"create zip failure");
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
    
    /********** Unzipping ********/
    
    outputPath = [self _cachesPath:@"UnicodePassword"];
    
    NSError *error = nil;
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    success = [SSZipArchive unzipFileAtPath:archivePath toDestination:outputPath overwrite:YES password:@"ꊐ⌒Ⅳ🤐" error:&error delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");
    
    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}


- (void)testUnzippingTruncatedFileFix {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"IncorrectHeaders" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"IncorrectHeaders"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");

    NSString *intendedReadmeTxtMD5 = @"31ac96301302eb388070c827447290b5";

    NSString *filePath = [outputPath stringByAppendingPathComponent:@"IncorrectHeaders/Readme.txt"];
    NSData *data = [NSData dataWithContentsOfFile:filePath];

    NSString *actualReadmeTxtMD5 = [self _calculateMD5Digest:data];
    XCTAssertTrue([actualReadmeTxtMD5 isEqualToString:intendedReadmeTxtMD5], @"Readme.txt MD5 digest should match original.");
}


- (void)testUnzippingWithSymlinkedFileInside {

    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"SymbolicLink" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"SymbolicLink"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSString *testSymlink = [outputPath stringByAppendingPathComponent:@"SymbolicLink/Xcode.app"];

    NSError *error = nil;
    NSDictionary *info = [[NSFileManager defaultManager] attributesOfItemAtPath: testSymlink error: &error];
    BOOL fileIsSymbolicLink = info[NSFileType] == NSFileTypeSymbolicLink;
    XCTAssertTrue(fileIsSymbolicLink, @"Symbolic links should persist from the original archive to the outputted files.");
}

- (void)testUnzippingWithRelativeSymlink {

    NSString *resourceName = @"RelativeSymbolicLink";
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:resourceName ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:resourceName];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    // Determine where the symlinks are
    NSString *subfolderName = @"symlinks";
    NSString *testBasePath = [NSString pathWithComponents:@[outputPath]];
    NSString *testSymlinkFolder = [NSString pathWithComponents:@[testBasePath, subfolderName, @"folderSymlink"]];
    NSString *testSymlinkFile = [NSString pathWithComponents:@[testBasePath, subfolderName, @"fileSymlink"]];

    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:testSymlinkFile error: nil];
    BOOL fileIsSymbolicLink = fileAttributes[NSFileType] == NSFileTypeSymbolicLink;
    XCTAssertTrue(fileIsSymbolicLink, @"Relative symbolic links should persist from the original archive to the outputted files.");

    NSDictionary *folderAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:testSymlinkFolder error: nil];
    BOOL folderIsSymbolicLink = folderAttributes[NSFileType] == NSFileTypeSymbolicLink;
    XCTAssertTrue(folderIsSymbolicLink, @"Relative symbolic links should persist from the original archive to the outputted files.");
}

- (void)testUnzippingWithUnicodeFilenameInside {

    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Unicode" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Unicode"];

    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    bool unicodeFilenameWasExtracted = [[NSFileManager defaultManager] fileExistsAtPath:[outputPath stringByAppendingPathComponent:@"Accént.txt"]];

    bool unicodeFolderWasExtracted = [[NSFileManager defaultManager] fileExistsAtPath:[outputPath stringByAppendingPathComponent:@"Fólder/Nothing.txt"]];

    XCTAssertTrue(unicodeFilenameWasExtracted, @"Files with filenames in unicode should be extracted properly.");
    XCTAssertTrue(unicodeFolderWasExtracted, @"Folders with names in unicode should be extracted propertly.");
}

/// Issue #507
- (void)testZippingWithUnicodeFilenameInside {
    
    NSString *workPath = [self _cachesPath:@"UnicodeZipping"];
    NSString *filePath = [workPath stringByAppendingPathComponent:@"17 What I’ve Been Looking For.pdf"];
    NSString *zipPath = [workPath stringByAppendingPathComponent:@"UnicodeZipping.zip"];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    
    BOOL success = [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:@[filePath]];
    XCTAssertTrue(success, @"zip failure");
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    success = [SSZipArchive unzipFileAtPath:zipPath toDestination:workPath delegate:nil];
    XCTAssertTrue(success, @"unzip failure");
    
    bool unicodeFilenameWasExtracted = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    XCTAssertTrue(unicodeFilenameWasExtracted, @"Files with filenames in unicode should be extracted properly.");
}

- (void)testZippingEmptyArchive {
    
    NSString *inputPath = [self _cachesPath:@"Empty"];
    XCTAssert(![[NSFileManager defaultManager] enumeratorAtPath:inputPath].nextObject, @"The Empty cache folder should always be empty.");
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    NSString *zipPath = [outputPath stringByAppendingPathComponent:@"Empty.zip"];
    NSString *zipPath2 = [outputPath stringByAppendingPathComponent:@"EmptyWithParentDirectory.zip"];
    
    BOOL success = [SSZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:inputPath keepParentDirectory:NO];
    XCTAssertTrue(success, @"create zip failure");
    success = [SSZipArchive createZipFileAtPath:zipPath2 withContentsOfDirectory:inputPath keepParentDirectory:YES];
    XCTAssertTrue(success, @"create zip failure");
    long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:zipPath error:nil][NSFileSize] longLongValue];
    long long fileSize2 = [[[NSFileManager defaultManager] attributesOfItemAtPath:zipPath2 error:nil][NSFileSize] longLongValue];
    XCTAssert(fileSize < fileSize2, @"keepParentDirectory should produce a strictly bigger archive.");
}

- (void)testZippingAndUnzippingEmptyDirectoryWithPassword {
    
    NSString *inputPath = [self _cachesPath:@"Empty"];
    XCTAssert(![[NSFileManager defaultManager] enumeratorAtPath:inputPath].nextObject, @"The Empty cache folder should always be empty.");
    NSString *outputPath = [self _cachesPath:@"Zipped"];
    NSString *zipPath = [outputPath stringByAppendingPathComponent:@"EmptyWithParentDirectory.zip"];
    
    BOOL success = [SSZipArchive createZipFileAtPath:zipPath withContentsOfDirectory:inputPath keepParentDirectory:YES withPassword:@"password"];
    XCTAssertTrue(success, @"create zip failure");
    
    outputPath = [self _cachesPath:@"EmptyDirectory"];
    
    // unzipping a directory doesn't require a password
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:nil error:nil delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
}

- (void)testUnzippingEmptyArchive {
    
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Empty" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Empty"];
    
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:nil];
    XCTAssertTrue(success, @"unzip failure");
}

- (void)testZippingAndUnzippingForDate {

    // use extracted files from [-testUnzipping]
    [self testUnzipping];
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"]];

    NSDictionary *originalFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[inputPath stringByAppendingPathComponent:@"Readme.markdown"] error:nil];

    NSString *outputPath = [self _cachesPath:@"ZippedDate"];
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];

    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];
    XCTAssertTrue(success, @"create zip failure");
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    success = [SSZipArchive unzipFileAtPath:archivePath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");

    NSDictionary *createdFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[outputPath stringByAppendingPathComponent:@"Readme.markdown"] error:nil];

    XCTAssertEqualObjects(originalFileAttributes[NSFileCreationDate], createdFileAttributes[@"NSFileCreationDate"], @"Original file creationDate should match created one");
}


- (void)testZippingAndUnzippingForPermissions {
    // File we're going to test permissions on before and after zipping
    NSString *targetFile = @"/Contents/MacOS/TestProject";


    /********** Zipping ********/

    // The .app file we're going to zip up
    NSString *inputFile = [[NSBundle bundleForClass: [self class]] pathForResource:@"PermissionsTestApp" ofType:@"app"];

    // The path to the target file in the app before zipping
    NSString *targetFilePreZipPath = [inputFile stringByAppendingPathComponent:targetFile];

    // Atribtues for the target file before zipping
    NSDictionary *preZipAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:targetFilePreZipPath error:nil];

    // Directory to output our created zip file
    NSString *outputDir = [self _cachesPath:@"PermissionsTest"];
    // The path to where the archive shall be created
    NSString *archivePath = [outputDir stringByAppendingPathComponent:@"TestAppArchive.zip"];

    // Create the zip file using the contents of the .app file as the input
    BOOL success = [SSZipArchive createZipFileAtPath:archivePath withContentsOfDirectory:inputFile];
    XCTAssertTrue(success, @"create zip failure");

    /********** Un-zipping *******/

    // Using this newly created zip file, unzip it
    success = [SSZipArchive unzipFileAtPath:archivePath toDestination:outputDir];
    XCTAssertTrue(success, @"unzip failure");
    
    // Get the path to the target file after unzipping
    NSString *targetFilePath = [outputDir stringByAppendingPathComponent:@"/Contents/MacOS/TestProject"];

    // Get the file attributes of the target file following the unzipping
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:targetFilePath error:nil];

    
    NSInteger permissions = ((NSNumber *)fileAttributes[NSFilePosixPermissions]).longValue;
    NSInteger preZipPermissions = ((NSNumber *)preZipAttributes[NSFilePosixPermissions]).longValue;

    // Compare the value of the permissions attribute to assert equality
    XCTAssertEqual(permissions, preZipPermissions, @"File permissions should be retained during compression and de-compression");
}

- (void)testUnzippingWithCancel {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Cancel1"];

    CancelDelegate *delegate = [[CancelDelegate alloc] init];
    delegate.numFilesToUnzip = 1;

    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertFalse(success);
    XCTAssertEqual(delegate.numFilesUnzipped, 1);
    XCTAssertFalse(delegate.didUnzipArchive);
    XCTAssertNotEqual(delegate.loaded, delegate.total);

    outputPath = [self _cachesPath:@"Cancel2"];

    delegate = [[CancelDelegate alloc] init];
    delegate.numFilesToUnzip = 1000;

    success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    XCTAssertEqual(delegate.numFilesUnzipped, 2);
    XCTAssertTrue(delegate.didUnzipArchive);
    XCTAssertEqual(delegate.loaded, delegate.total);
}

// Commented out to avoid checking in several gig file into the repository. Simply add a file named
// `LargeArchive.zip` to the project and uncomment out these lines to test.
//
//- (void)testUnzippingLargeFiles {
//	NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"LargeArchive" ofType:@"zip"];
//	NSString *outputPath = [self _cachesPath:@"Large"];
//
//  BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath];
//  XCTAssertTrue(success, @"unzip failure");
//}

-(void)testShouldProvidePathOfUnzippedFileInDelegateCallback {
    CollectingDelegate *collector = [CollectingDelegate new];
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Regular"];
    
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:collector];
    XCTAssertTrue(success, @"unzip failure");
    
    XCTAssertEqualObjects(collector.files[0], [outputPath stringByAppendingString:@"/LICENSE"]);
    XCTAssertEqualObjects(collector.files[1], [outputPath stringByAppendingString:@"/Readme.markdown"]);
}

- (void)testUnzippingFileWithPathTraversalName {
    
    // This zip archive contains a file titled '../../../../../../../../../../..//tmp/test.txt'. SSZipArchive should
    // ignore the path traversing and write the file to "tmp/test.txt"
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"PathTraversal" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Traversal"];
    
    id<SSZipArchiveDelegate> delegate = [ProgressDelegate new];
    BOOL success = [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];
    XCTAssertTrue(success, @"unzip failure");
    
    NSString *expectedFile = [outputPath stringByAppendingPathComponent:@"tmp/test.txt"];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:expectedFile];
    
    XCTAssertTrue(fileExists, @"Path traversal characters should not be followed when unarchiving a file");
}

- (void)testPathSanitation {
    NSDictionary<NSString *, NSString *> *tests =
    @{
      // path traversal
      @"../../../../../../../../../../../tmp/test.txt": @"tmp/test.txt",
      // path traversal, Windows style
      @"..\\..\\..\\..\\..\\..\\..\\..\\..\\..\\..\\tmp\\test.txt": @"tmp/test.txt",
      // relative path
      @"a/b/../c.txt": @"a/c.txt",
      // path traversal without slash
      @"..": @"",
      // permissions override
      @"./": @"",
      @".": @"",
      // unicode and spaces in folder name and file name
      @"example/../à: 𝚨 󌞑/你 好.txt": @"à: 𝚨 󌞑/你 好.txt",
      // unicode that looks like '.' or '/' in ascii decomposition
      @"a/ğ/../b": @"a/b",
      @"a/⸮/b/.ⸯ/c/⼮./d": @"a/⸮/b/.ⸯ/c/⼮./d",
      // scheme in name
      @"file:a/../../../usr/bin": @"usr/bin",
      };
    for (NSString *str in tests) {
        //NSLog(@"%@", str);
        XCTAssertTrue([tests[str] isEqualToString:[str _sanitizedPath]], @"Path should be sanitized for traversal");
    }
}

#pragma mark - Private

- (NSString *)_cachesPath:(NSString *)directory {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject
                      stringByAppendingPathComponent:@"com.samsoffes.ssziparchive.tests"];
    if (directory) {
        path = [path stringByAppendingPathComponent:directory];
    }

    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

    return path;
}


// Taken from https://github.com/samsoffes/sstoolkit/blob/master/SSToolkit/NSData+SSToolkitAdditions.m
- (NSString *)_calculateMD5Digest:(NSData *)data {
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5(data.bytes, (unsigned int)data.length, digest);
    NSMutableString *ms = [NSMutableString string];
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ms appendFormat: @"%02x", (int)(digest[i])];
    }
    return [ms copy];
}

@end
