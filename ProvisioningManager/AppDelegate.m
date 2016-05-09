//
//  AppDelegate.m
//  ProvisioningManager
//
//  Created by Tue Nguyen on 8/10/15.
//  Copyright (c) 2015 Pharaoh. All rights reserved.
//

#import "AppDelegate.h"
#import "SigningIdentity.h"
#import "Provisioning.h"

@interface AppDelegate ()<NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (strong, nonatomic) NSMutableArray *provisioningArray;
@property (weak) IBOutlet NSTableView *tableView;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;

@end

@implementation AppDelegate

- (void)buildListIdentity {
    self.provisioningArray = [NSMutableArray new];
    NSArray *keychainsIdentities = [SigningIdentity keychainsIdenities];
    
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    
    NSString *mobileProvisioningFolder = [library stringByAppendingPathComponent:@"MobileDevice/Provisioning Profiles"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:mobileProvisioningFolder error:nil];
    
    for (NSString *name in contents) {
        if ([name hasPrefix:@"."]) continue;
        if ([name.pathExtension caseInsensitiveCompare:@"mobileprovision"] != NSOrderedSame) continue;
        
        NSString *path = [mobileProvisioningFolder stringByAppendingPathComponent:name];
        Provisioning *provisioning = [[Provisioning alloc] initWithPath:path];
        [self.provisioningArray addObject:provisioning];
    }
    [self.provisioningArray sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    
    for (Provisioning *provision in self.provisioningArray) {
        for (SigningIdentity *identity in provision.signingIdentities) {
            BOOL matchInKeychains = NO;
            
            for (SigningIdentity *keyhainsIdentity in keychainsIdentities) {
                if ([identity.certificateData isEqualToData:keyhainsIdentity.certificateData]) {
                    matchInKeychains = YES;
                    provision.matchInKeychains = matchInKeychains;
                    provision.signingIdentity = keyhainsIdentity;
                    break;
                }
            }
        }
        
        if ([provision.expirationDate timeIntervalSinceNow] > 0) {
            provision.status = provision.matchInKeychains ? @"Valid" : @"Missing Identity";
        } else {
            provision.status = @"Expired";
        }
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    self.dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    [self buildListIdentity];
    [self.provisioningArray sortUsingDescriptors:[self.tableView sortDescriptors]];
    [self.tableView reloadData];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}
#pragma mark - UITableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.provisioningArray.count;
}

/* This method is required for the "Cell Based" TableView, and is optional for the "View Based" TableView. If implemented in the latter case, the value will be set to the view at a given row/column if the view responds to -setObjectValue: (such as NSControl and NSTableCellView).
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Provisioning *provisioning = self.provisioningArray[row];
    if ([tableColumn.identifier isEqual:@"name"]) {
        return provisioning.name;
    }
    return provisioning.creationDate;
}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Provisioning *provisioning = self.provisioningArray[row];
    // Retrieve to get the @"MyView" from the pool or,
    // if no version is available in the pool, load the Interface Builder version
    NSTableCellView *result = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    // Set the stringValue of the cell's text field to the nameArray value at row
    if ([tableColumn.identifier isEqualToString:@"name"]) {
        result.textField.stringValue = provisioning.name;
    } else if ([tableColumn.identifier isEqualToString:@"identity"]) {
        NSString *commonName = provisioning.signingIdentity.commonName;
        if (!commonName) {
            commonName = [[provisioning.signingIdentities firstObject] commonName];
        }
        if (!commonName) {
            commonName = @"";
        }
        result.textField.stringValue = commonName;
    } else if ([tableColumn.identifier isEqualToString:@"creationDate"]) {
        result.textField.stringValue = [self.dateFormatter stringFromDate:provisioning.creationDate];
    } else if ([tableColumn.identifier isEqualToString:@"expirationDate"]) {
        result.textField.stringValue = [self.dateFormatter stringFromDate:provisioning.expirationDate];
    } else if ([tableColumn.identifier isEqualToString:@"status"]) {
        if ([provisioning.expirationDate timeIntervalSinceNow] > 0) {
            result.textField.stringValue = provisioning.matchInKeychains ? @"Valid" : @"Missing Identity";
            result.textField.textColor = provisioning.matchInKeychains ? [NSColor blackColor] : [NSColor orangeColor];
        } else {
            result.textField.stringValue = @"Expired";
            result.textField.textColor = [NSColor redColor];
        }
    }
    
    // Return the result
    return result;
}
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    NSSortDescriptor *sortByColumn = [tableView sortDescriptors].firstObject;
    NSMutableArray *sortDescriptors = [NSMutableArray arrayWithObject:sortByColumn];
    if ([sortByColumn.key isEqualToString:@"creationDate"]) {
        [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    } else if ([sortByColumn.key isEqualToString:@"name"]) {
        [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    } else {
        [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
        [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    }
    [self.provisioningArray sortUsingDescriptors:sortDescriptors];
    [tableView reloadData];
}
#pragma mark - Menu Action
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(delete:) ||
        menuItem.action == @selector(revealInFinder:)) {
        return self.tableView.numberOfSelectedRows > 0;
    } else if (menuItem.action == @selector(export:)) {
        return self.tableView.numberOfSelectedRows >= 1;
    } else if (menuItem.action == @selector(removeDuplicate:)) {
        return self.tableView.numberOfSelectedRows == 1;
    }
    return [self respondsToSelector:menuItem.action];
}
- (IBAction)delete:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSWarningAlertStyle;
    alert.messageText = @"Are you sure you want to delete those provisioning?";
    [alert addButtonWithTitle:@"Delete"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSFileManager *fm = [NSFileManager defaultManager];
            [[self.tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                Provisioning *provisioning = self.provisioningArray[idx];
                [fm removeItemAtPath:provisioning.path error:nil];
            }];
            [self.provisioningArray removeObjectsAtIndexes:[self.tableView selectedRowIndexes]];
            [self.tableView removeRowsAtIndexes:self.tableView.selectedRowIndexes withAnimation:NSTableViewAnimationSlideUp];
        }
    }];
}

- (IBAction)revealInFinder:(id)sender {
    NSMutableArray *selectedURLs = [NSMutableArray new];
    [[self.tableView selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        Provisioning *provisioning = self.provisioningArray[idx];
        [selectedURLs addObject:[NSURL fileURLWithPath:provisioning.path]];
    }];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:selectedURLs];
}

- (IBAction)export:(id)sender {
    if (self.tableView.selectedRowIndexes.count == 1) {
        Provisioning *provisioning = self.provisioningArray[self.tableView.selectedRow];
        NSSavePanel *savePanel = [NSSavePanel savePanel];
        savePanel.allowedFileTypes = @[@"mobileprovision"];
        savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@", provisioning.name];
        [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
            NSString *savePath = savePanel.URL.path;
            if (result == NSFileHandlingPanelOKButton) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
                    [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
                }
                [[NSFileManager defaultManager] copyItemAtPath:provisioning.path toPath:savePath error:nil];
            }
        }];
    } else {
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        openPanel.canChooseFiles = NO;
        openPanel.canChooseDirectories = YES;
        openPanel.canCreateDirectories = YES;
        [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton) {
                NSString *saveDir = openPanel.URL.path;
                if (result == NSFileHandlingPanelOKButton) {
                    [self.tableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                        Provisioning *provisioning = self.provisioningArray[idx];
                        NSString *savePath = [[saveDir stringByAppendingPathComponent:provisioning.name] stringByAppendingPathExtension:@"mobileprovision"];
                        if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
                            [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
                        }
                        [[NSFileManager defaultManager] copyItemAtPath:provisioning.path toPath:savePath error:nil];
                    }];
                    
                }
            }
        }];
    }
}

- (IBAction)reload:(id)sender {
    [self buildListIdentity];
    [self.tableView reloadData];
}
- (IBAction)removeDuplicate:(id)sender {
    Provisioning *provisioning = self.provisioningArray[self.tableView.selectedRow];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSWarningAlertStyle;
    alert.messageText = @"Are you sure you want to remove duplicated provisioning?";
    alert.informativeText = [NSString stringWithFormat:@"All provisioning with same name: \"%@\" and identity: \"%@\" will be deleted. The newest provisioning will be keep", provisioning.name, provisioning.signingIdentity.commonName];
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSFileManager *fm = [NSFileManager defaultManager];
            NSMutableArray *deletingProvisionings = [NSMutableArray array];
            Provisioning *latestPro = nil;
            for (Provisioning *pro in self.provisioningArray) {
                if ([pro.name isEqualToString:provisioning.name] &&
                    [pro.signingIdentity.commonName isEqualToString:provisioning.signingIdentity.commonName]) {
                    [deletingProvisionings addObject:pro];
                    
                    if (latestPro == nil) {
                        latestPro = pro;
                    } else if ([latestPro.creationDate compare:pro.creationDate] == NSOrderedAscending) {
                        //latest is older than pro
                        latestPro = pro;
                    }
                }
            }
            
            [deletingProvisionings removeObject:latestPro];
            for (Provisioning *pro in deletingProvisionings) {
                [fm removeItemAtPath:pro.path error:nil];
            }
            [self.provisioningArray removeObjectsInArray:deletingProvisionings];
            [self.tableView reloadData];
            
//            Provisioning *provisioning = self.provisioningArray[idx];
//            [fm removeItemAtPath:provisioning.path error:nil];
//            [self.provisioningArray removeObjectsAtIndexes:[self.tableView selectedRowIndexes]];
//            [self.tableView removeRowsAtIndexes:self.tableView.selectedRowIndexes withAnimation:NSTableViewAnimationSlideUp];
        }
    }];
}
@end
