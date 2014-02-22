//
//  AACViewController.m
//  AutoAddContact
//
//  Created by Keith Ermel on 2/21/14.
//  Copyright (c) 2014 Keith Ermel. All rights reserved.
//

#import "AACViewController.h"
#import <AddressBook/AddressBook.h>


typedef void(^ContactsAccessGranted)();
typedef void(^ContactsAccessDenied)();
typedef void(^MainThreadWorker)();


CFStringRef const kMoneypennyName           = CFSTR("Moneypenny");
CFStringRef const kMoneypennyEmail          = CFSTR("xdmoneypenny@outlook.com");
NSTimeInterval const kButtonAnimDuration    = 0.75;


@interface AACViewController ()
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIButton *removeMoneypennyButton;
@end


@implementation AACViewController


#pragma mark - Address Book 

-(void)checkContactsAccess
{
    [self hasAccessToAddressBook:^() {
        [self doOnMainThread:^{[self performMoneypennyContactStuff];}];
        
    } denied:^(ABAuthorizationStatus authStatus) {
        [self doOnMainThread:^{[self logStatus:@"Bummer. I don't have access to Contacts."];}];
    }];
}

-(void)hasAccessToAddressBook:(ContactsAccessGranted)accessGranted 
                       denied:(ContactsAccessDenied)accessDenied
{
    CFErrorRef anError = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &anError);
    ABAuthorizationStatus authStatus = ABAddressBookGetAuthorizationStatus();
    
    if (authStatus == kABAuthorizationStatusNotDetermined) {
        [self requestAccessWithAddressBook:addressBook 
                                   granted:accessGranted 
                                    denied:accessDenied];
    }
    else if (authStatus == kABAuthorizationStatusAuthorized) {accessGranted();}
    else if (authStatus == kABAuthorizationStatusDenied) {accessDenied();}
}

-(void)requestAccessWithAddressBook:(ABAddressBookRef)addressBook
                      granted:(ContactsAccessGranted)accessGranted
                       denied:(ContactsAccessDenied)accessDenied
{
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        if (granted) {accessGranted();}
        else {accessDenied();}
    });
}

-(ABRecordRef)retrieveContactWithName:(CFStringRef)contactName
{
    CFErrorRef anError = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &anError);
    CFArrayRef people = ABAddressBookCopyPeopleWithName(addressBook, contactName);
    
    if ((people != nil) && (CFArrayGetCount(people) > 0)) {
        ABRecordRef person = (ABRecordRef)CFBridgingRetain([(__bridge NSArray*)people objectAtIndex:0]);
        return person;
    }
    
    return nil;
}


#pragma mark - Moneypenny Contact 

-(BOOL)moneypennyContactDoesNotExist
{
    if ([self retrieveContactWithName:kMoneypennyName] != nil) {return NO;}
    return YES;
}

-(void)performMoneypennyContactStuff
{
    if ([self moneypennyContactDoesNotExist]) {
        if ([self addMoneypennyContactToAddressBook]) {
            [self logStatus:@"Moneypenny added to Contacts"];
            [self showRemoveMoneypennyButton];
        }
    }
    else {
        [self showRemoveMoneypennyButton];
        [self logStatus:@"Moneypenny is already in Contacts"];
    }
}

-(ABRecordRef)buildMoneypennyContact
{
	ABRecordRef moneypennyContact = ABPersonCreate();
	CFErrorRef error = NULL;
	ABMultiValueRef email = ABMultiValueCreateMutable(kABMultiStringPropertyType);
	bool didAdd = ABMultiValueAddValueAndLabel(email, kMoneypennyEmail, kABWorkLabel, NULL);
    
    if (didAdd == YES) {
		ABRecordSetValue(moneypennyContact, kABPersonEmailProperty, email, &error);
        ABRecordSetValue(moneypennyContact, kABPersonNicknameProperty, kMoneypennyName, &error);
        
		if (error == NULL) {
            return moneypennyContact;
        }
    }
    
    return nil;
}

-(BOOL)addMoneypennyContactToAddressBook
{
    ABRecordRef moneypennyContact = [self buildMoneypennyContact];
    if (moneypennyContact != nil) {
        NSLog(@"Created Moneypenny Contact");
        
        CFErrorRef error = NULL;
        ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
        if (error != NULL) {return [self logError:error];}
        
        if (ABAddressBookAddRecord(addressBook, moneypennyContact, &error)) {
            if (ABAddressBookSave(addressBook, &error)) {return YES;}
            else {return [self logError:error];}
        }
        else {return [self logError:error];}
    }
    
    return NO;
}

-(BOOL)removeMoneypennyContactFromAddressBook
{
    ABRecordRef moneypennyContact = [self retrieveContactWithName:kMoneypennyName];
    if (moneypennyContact != nil) {
        CFErrorRef error = NULL;
        ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
        if (error != NULL) {return [self logError:error];}
        
        if (ABAddressBookRemoveRecord(addressBook, moneypennyContact, &error)) {
            if (ABAddressBookSave(addressBook, &error)) {return YES;}
            else {return [self logError:error];}
        }
        else {return [self logError:error];}
    }
    return NO;
}


#pragma mark - Helpers

-(void)doOnMainThread:(MainThreadWorker)worker
{
    if ([NSThread isMainThread]) {
        worker();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{worker();});
    }
}


#pragma mark - UX

-(void)showRemoveMoneypennyButton
{
    self.removeMoneypennyButton.alpha = 0.0f;
    self.removeMoneypennyButton.hidden = NO;
    
    [UIView animateWithDuration:kButtonAnimDuration animations:^{
        self.removeMoneypennyButton.alpha = 1.0f;
    }];
}


#pragma mark - Actions

-(IBAction)removeMoneypennyAction:(id)sender
{
    if ([self removeMoneypennyContactFromAddressBook]) {
        self.removeMoneypennyButton.hidden = YES;
        [self logStatus:@"Moneypenny removed from Contacts"];
    }
}


#pragma mark - Status

-(void)logStatus:(NSString *)message
{
    NSLog(@"%@", message);
    self.statusLabel.text = message;
}

-(BOOL)logError:(CFErrorRef)anError
{
    if (anError != NULL) {
        NSError *error = (NSError *)CFBridgingRelease(anError);
        NSLog(@"error: %@", error.description);
        
        self.statusLabel.text = error.description;
        return NO;
    }
    return YES;
}


#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self checkContactsAccess];
}

@end
