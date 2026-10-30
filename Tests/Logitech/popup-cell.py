#!/usr/bin/env python3
"""Compile the actual production popup lookup, without the rest of the app.
AppKit owns cell realization; reproduce an unrealized bottom row in a real table.
No window is shown and no input events or HID operations are generated.
"""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
source = (root / "App/UI/Main/Tabs/ButtonTab/RemapTable/RemapTableUtility.m").read_text()
start = source.index("+ (NSPopUpButton *)getPopUpButtonAtRow:")
end = source.index("#pragma mark - Group rows", start)
method = source[start:end]
harness = r'''
#import <Cocoa/Cocoa.h>
#include <assert.h>
@interface RemapTableUtility : NSObject
+ (NSPopUpButton *)getPopUpButtonAtRow:(NSUInteger)row fromTableView:(NSTableView *)table;
@end
@implementation RemapTableUtility
METHOD
@end
@interface Rows : NSObject <NSTableViewDataSource, NSTableViewDelegate> @end
@implementation Rows
- (NSInteger)numberOfRowsInTableView:(NSTableView *)table { return 100; }
- (NSView *)tableView:(NSTableView *)table viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    NSTableCellView *cell = [NSTableCellView new];
    NSPopUpButton *popup = [NSPopUpButton new];
    [popup addItemWithTitle:@"Harmless test action"];
    [cell addSubview:popup];
    return cell;
}
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSTableView *table = [[NSTableView alloc] initWithFrame:NSMakeRect(0,0,300,50)];
    [table addTableColumn:[[NSTableColumn alloc] initWithIdentifier:@"effect"]];
    Rows *rows = [Rows new]; table.dataSource = rows; table.delegate = rows;
    [table reloadData];
    assert([table viewAtColumn:0 row:99 makeIfNecessary:NO] == nil);
    NSPopUpButton *popup = [RemapTableUtility getPopUpButtonAtRow:99 fromTableView:table];
    assert([popup isKindOfClass:NSPopUpButton.class]);
    assert([popup.titleOfSelectedItem isEqual:@"Harmless test action"]);
    puts("PASS: production lookup realizes offscreen Button7 popup cell without exception");
} }
'''.replace("METHOD", method)
with tempfile.TemporaryDirectory(prefix="mmf-popup-test-") as work:
    path = Path(work)
    (path / "test.m").write_text(harness)
    subprocess.run(["xcrun", "clang", "-fobjc-arc", "-framework", "Cocoa", str(path / "test.m"), "-o", str(path / "test")], check=True)
    subprocess.run([str(path / "test")], check=True)
