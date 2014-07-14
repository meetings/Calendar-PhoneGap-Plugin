#import "Calendar.h"
#import <Cordova/CDV.h>
#import <EventKitUI/EventKitUI.h>
#import <EventKit/EventKit.h>

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@implementation Calendar
@synthesize eventStore, hasAccess;

#pragma mark Initialisation functions

- (CDVPlugin*) initWithWebView:(UIWebView*)theWebView
{
    self = (Calendar*)[super initWithWebView:theWebView];
    if (self) {
        //[self setup];

        //STEROIDSIFIED
        // [self initEventStoreWithCalendarCapabilities];
    }
    return self;
}

- (void)initEventStoreWithCalendarCapabilities {
    __block BOOL accessGranted = NO;
    eventStore= [[EKEventStore alloc] init];
    if([eventStore respondsToSelector:@selector(requestAccessToEntityType:completion:)]) {
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
            accessGranted = granted;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    } else { // we're on iOS 5 or older
        self.hasAccess = true;
        accessGranted = YES;
    }

    if (accessGranted) {
        self.hasAccess = true;
        self.eventStore = eventStore;
    } else {
        self.hasAccess = false;
    }
}

#pragma mark Helper Functions

- (void)createEventWithCalendar:(CDVInvokedUrlCommand*)command
                       calendar: (EKCalendar *) calendar {
    NSString *callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];

    NSString* title      = [options objectForKey:@"title"];
    NSString* location   = [options objectForKey:@"location"];
    NSString* notes      = [options objectForKey:@"notes"];
    NSNumber* startTime  = [options objectForKey:@"startTime"];
    NSNumber* endTime    = [options objectForKey:@"endTime"];

    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];

    NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis

    EKEvent *myEvent = [EKEvent eventWithEventStore: self.eventStore];
    myEvent.title = title;
    myEvent.location = location;
    myEvent.notes = notes;
    myEvent.startDate = myStartDate;

    int duration = _endInterval - _startInterval;
    int moduloDay = duration % (60*60*24);
    if (moduloDay == 0) {
        myEvent.allDay = YES;
        myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval-1];
    } else {
        myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];
    }
    myEvent.calendar = calendar;

    // TODO base on passed alarm
    EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*60*60];
    [myEvent addAlarm:reminder];

    NSError *error = nil;
    [self.eventStore saveEvent:myEvent span:EKSpanThisEvent error:&error];

    if (error) {
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
        [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
    } else {
        NSLog(@"Reached Success");
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
    }
}

- (void)createEventWithCalendarOptions:(CDVInvokedUrlCommand*)command
                              calendar: (EKCalendar *) calendar {
    NSString *callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];

    NSString* title      = [options objectForKey:@"title"];
    NSString* location   = [options objectForKey:@"location"];
    NSString* notes      = [options objectForKey:@"notes"];
    NSNumber* startTime  = [options objectForKey:@"startTime"];
    NSNumber* endTime    = [options objectForKey:@"endTime"];

    NSDictionary* calOptions = [options objectForKey:@"options"];
    NSNumber* firstReminderMinutes = [calOptions objectForKey:@"firstReminderMinutes"];
    NSNumber* secondReminderMinutes = [calOptions objectForKey:@"secondReminderMinutes"];

    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];

    NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis

    EKEvent *myEvent = [EKEvent eventWithEventStore: self.eventStore];
    myEvent.title = title;
    myEvent.location = location;
    myEvent.notes = notes;
    myEvent.startDate = myStartDate;

    int duration = _endInterval - _startInterval;
    int moduloDay = duration % (60*60*24);
    if (moduloDay == 0) {
        myEvent.allDay = YES;
        myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval-1];
    } else {
        myEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];
    }
    myEvent.calendar = calendar;

    if (firstReminderMinutes != (id)[NSNull null]) {
        EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*firstReminderMinutes.intValue*60];
        [myEvent addAlarm:reminder];
    }

    if (secondReminderMinutes != (id)[NSNull null]) {
        EKAlarm *reminder = [EKAlarm alarmWithRelativeOffset:-1*secondReminderMinutes.intValue*60];
        [myEvent addAlarm:reminder];
    }

    NSError *error = nil;
    [self.eventStore saveEvent:myEvent span:EKSpanThisEvent error:&error];

    if (error) {
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
        [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
    } else {
        NSLog(@"Reached Success");
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
    }
}

-(void)modifyEventWithCalendar:(CDVInvokedUrlCommand*)command
                      calendar: (EKCalendar *) calendar {
    NSString *callbackId = command.callbackId;

    NSDictionary* options = [command.arguments objectAtIndex:0];

    NSString* title      = [options objectForKey:@"title"];
    NSString* location   = [options objectForKey:@"location"];
    NSString* notes      = [options objectForKey:@"notes"];
    NSNumber* startTime  = [options objectForKey:@"startTime"];
    NSNumber* endTime    = [options objectForKey:@"endTime"];

    NSString* ntitle     = [options objectForKey:@"newTitle"];
    NSString* nlocation  = [options objectForKey:@"newLocation"];
    NSString* nnotes     = [options objectForKey:@"newNotes"];
    NSNumber* nstartTime = [options objectForKey:@"newStartTime"];
    NSNumber* nendTime   = [options objectForKey:@"newEndTime"];

    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];

    NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis
    NSDate *myEndDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

    // Find matches
    NSArray *matchingEvents = [self findEKEventsWithTitle:title location:location notes:notes startDate:myStartDate endDate:myEndDate calendar:calendar];

    if (matchingEvents.count == 1) {
        // Presume we have to have an exact match to modify it!
        // Need to load this event from an EKEventStore so we can edit it
        EKEvent *theEvent = [self.eventStore eventWithIdentifier:((EKEvent*)[matchingEvents lastObject]).eventIdentifier];
        if (ntitle) {
            theEvent.title = ntitle;
        }
        if (nlocation) {
            theEvent.location = nlocation;
        }
        if (nnotes) {
            theEvent.notes = nnotes;
        }
        if (nstartTime) {
            NSTimeInterval _nstartInterval = [nstartTime doubleValue] / 1000; // strip millis
            theEvent.startDate = [NSDate dateWithTimeIntervalSince1970:_nstartInterval];
        }
        if (nendTime) {
            NSTimeInterval _nendInterval = [nendTime doubleValue] / 1000; // strip millis
            theEvent.endDate = [NSDate dateWithTimeIntervalSince1970:_nendInterval];
        }

        // Now save the new details back to the store
        NSError *error = nil;
        [self.eventStore saveEvent:theEvent span:EKSpanThisEvent error:&error];

        // Check error code + return result
        if (error) {
            CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
            [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
        } else {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
        }
    } else {
        // Otherwise return a no result error (could be more than 1, but not a biggie)
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
    }
}


- (void)deleteEventFromCalendar:(CDVInvokedUrlCommand*)command
                       calendar: (EKCalendar *) calendar {

    NSString *callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];

    NSString* title      = [options objectForKey:@"title"];
    NSString* location   = [options objectForKey:@"location"];
    NSString* notes      = [options objectForKey:@"notes"];
    NSNumber* startTime  = [options objectForKey:@"startTime"];
    NSNumber* endTime    = [options objectForKey:@"endTime"];

    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];

    NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis
    NSDate *myEndDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];

    NSArray *matchingEvents = [self findEKEventsWithTitle:title location:location notes:notes startDate:myStartDate endDate:myEndDate calendar:calendar];

    NSError *error = NULL;
    for (EKEvent * event in matchingEvents) {
        [self.eventStore removeEvent:event span:EKSpanThisEvent error:&error];
    }

    if (error) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
        [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
    } else {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self writeJavascript:[pluginResult toSuccessCallbackString:callbackId]];
    }
}

-(NSArray*)findEKEventsWithTitle: (NSString *)title
                        location: (NSString *)location
                           notes: (NSString *)notes
                       startDate: (NSDate *)startDate
                         endDate: (NSDate *)endDate
                        calendar: (EKCalendar *) calendar {

    // Build up a predicateString - this means we only query a parameter if we actually had a value in it
    NSMutableString *predicateString= [[NSMutableString alloc] initWithString:@""];
    if (title != (id)[NSNull null] && title.length > 0) {
        [predicateString appendString:[NSString stringWithFormat:@"title == '%@'", title]];
    }
    if (location != (id)[NSNull null] && location.length > 0) {
        [predicateString appendString:[NSString stringWithFormat:@" AND location == '%@'", location]];
    }
    if (notes != (id)[NSNull null] && notes.length > 0) {
        [predicateString appendString:[NSString stringWithFormat:@" AND notes == '%@'", notes]];
    }

    NSPredicate *matches = [NSPredicate predicateWithFormat:predicateString];

    NSArray *calendarArray = [NSArray arrayWithObject:calendar];

    NSArray *datedEvents = [self.eventStore eventsMatchingPredicate:[eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:calendarArray]];

    NSArray *matchingEvents = [datedEvents filteredArrayUsingPredicate:matches];

    return matchingEvents;
}

-(EKCalendar*)findEKCalendar: (NSString *)calendarName {
    for (EKCalendar *thisCalendar in self.eventStore.calendars){
        NSLog(@"Calendar: %@", thisCalendar.title);
        if ([thisCalendar.title isEqualToString:calendarName]) {
            return thisCalendar;
        }
    }
    NSLog(@"No match found for calendar with name: %@", calendarName);
    return nil;
}

-(EKSource*)findEKSource {
    // if iCloud is on, it hides the local calendars, so check for iCloud first
    for (EKSource *source in self.eventStore.sources) {
        if (source.sourceType == EKSourceTypeCalDAV && [source.title isEqualToString:@"iCloud"]) {
            return source;
        }
    }

    // ok, not found.. so it's a local calendar
    for (EKSource *source in self.eventStore.sources) {
        if (source.sourceType == EKSourceTypeLocal) {
            return source;
        }
    }
    return nil;
}

#pragma mark Cordova functions

//STEROIDSIFIED
- (void)init:(CDVInvokedUrlCommand *)command {

    [self.commandDelegate runInBackground:^{
        [self initEventStoreWithCalendarCapabilities];

        if (self.hasAccess) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                              messageAsString:@"Access not granted"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    }];
}

- (void)listCalendars:(CDVInvokedUrlCommand*)command {
    NSArray * calendars = self.eventStore.calendars;
    // TODO when iOS 5 support is no longer needed, change the line above by the line below (and a few other places as well)
    // NSArray * calendars = [self.eventStore calendarsForEntityType:EKEntityTypeEvent];

    NSString *defaultCalendarIdentifier = self.eventStore.defaultCalendarForNewEvents.calendarIdentifier;

    [self.commandDelegate runInBackground:^{
        NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:calendars.count];
        for (EKCalendar *thisCalendar in calendars){

            BOOL isDefault = thisCalendar.calendarIdentifier == defaultCalendarIdentifier;
            NSNumber *boolNumber = [NSNumber numberWithBool:isDefault];

            NSMutableDictionary *entry = [NSMutableDictionary dictionary];

            [entry setObject: thisCalendar.calendarIdentifier forKey:@"id" ];
            [entry setObject: thisCalendar.title forKey:@"name" ];
            [entry setObject: boolNumber forKey:@"defaultCalendarForNewEvents" ];

            [finalResults addObject:entry];
        }

        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:finalResults];
        //[self writeJavascript:[result toSuccessCallbackString:callbackId]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

- (void)createEventInNamedCalendar:(CDVInvokedUrlCommand*)command {
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* calendarName = [options objectForKey:@"calendarName"];
    EKCalendar* calendar = [self findEKCalendar:calendarName];
    if (calendar == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
        [self writeJavascript:[result toErrorCallbackString:command.callbackId]];
    } else {
        [self createEventWithCalendar:command calendar:calendar];
    }
}

- (void)listEventsInRange:(CDVInvokedUrlCommand*)command {

}

- (void)createEventWithOptions:(CDVInvokedUrlCommand*)command {
    EKCalendar* calendar = self.eventStore.defaultCalendarForNewEvents;
    if (calendar == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
        [self writeJavascript:[result toErrorCallbackString:command.callbackId]];
    } else {
        [self createEventWithCalendarOptions:command calendar:calendar];
    }
}

- (void)createEventInteractively:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Method not supported on iOS"];
    [self writeJavascript:[result toErrorCallbackString:callbackId]];
}

-(void)deleteEventFromNamedCalendar:(CDVInvokedUrlCommand*)command {
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* calendarName = [options objectForKey:@"calendarName"];
    EKCalendar* calendar = [self findEKCalendar:calendarName];
    if (calendar == nil) {
        NSString *callbackId = command.callbackId;
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
        [self writeJavascript:[result toErrorCallbackString:callbackId]];
    } else {
        [self deleteEventFromCalendar:command calendar:calendar];
    }
}


-(void)deleteEvent:(CDVInvokedUrlCommand*)command {
    EKCalendar* calendar = self.eventStore.defaultCalendarForNewEvents;
    if (calendar == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
        [self writeJavascript:[result toErrorCallbackString:command.callbackId]];
    } else {
        [self deleteEventFromCalendar:command calendar: calendar];
    }
}


-(void)modifyEventInNamedCalendar:(CDVInvokedUrlCommand*)command {
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* calendarName = [options objectForKey:@"calendarName"];
    EKCalendar* calendar = [self findEKCalendar:calendarName];
    if (calendar == nil) {
        NSString *callbackId = command.callbackId;
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
        [self writeJavascript:[result toErrorCallbackString:callbackId]];
    } else {
        [self modifyEventWithCalendar:command calendar:calendar];
    }
}


-(void)modifyEvent:(CDVInvokedUrlCommand*)command {
    EKCalendar* calendar = self.eventStore.defaultCalendarForNewEvents;
    if (calendar == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
        [self writeJavascript:[result toErrorCallbackString:command.callbackId]];
    } else {
        [self modifyEventWithCalendar:command calendar: calendar];
    }
}


-(void)findAllEventsInNamedCalendar:(CDVInvokedUrlCommand*)command {
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* calendarName = [options objectForKey:@"calendarName"];
    EKCalendar* calendar = [self findEKCalendar:calendarName];

    [self.commandDelegate runInBackground:^{

        if (calendar == nil) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Could not find calendar"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            NSDate* endDate =  [NSDate dateWithTimeIntervalSinceNow:[[NSDate distantFuture] timeIntervalSinceReferenceDate]];
            NSArray *calendarArray = [NSArray arrayWithObject:calendar];
            NSPredicate *fetchCalendarEvents = [eventStore predicateForEventsWithStartDate:[NSDate date] endDate:endDate calendars:calendarArray];
            NSArray *matchingEvents = [eventStore eventsMatchingPredicate:fetchCalendarEvents];

            NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:matchingEvents.count];

            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

            // Stringify the results - Cordova can't deal with Obj-C objects
            for (EKEvent * event in matchingEvents) {
                //STEROIDSIFIED TOTALLY
                NSMutableDictionary *betterEvent = [NSMutableDictionary dictionary];

                if (event.availability) {
                    switch (event.availability) {
                        case EKEventAvailabilityBusy:
                            [betterEvent setObject: @"busy" forKey:@"availability"];
                            break;
                        case EKEventAvailabilityFree:
                            [betterEvent setObject: @"free" forKey:@"availability"];
                            break;
                        case EKEventAvailabilityTentative:
                            [betterEvent setObject: @"tentative" forKey:@"availability"];
                            break;
                        case EKEventAvailabilityUnavailable:
                            [betterEvent setObject: @"unavailable" forKey:@"availability"];
                            break;
                        default:
                            [betterEvent setObject: @"notSupported" forKey:@"availability"];
                            break;
                    }
                }

                if (event.calendarItemExternalIdentifier) {
                    [betterEvent setObject:event.calendarItemExternalIdentifier forKey:@"calendarItemExternalIdentifier"];
                }

                if (event.startDate) {
                    NSTimeInterval ti = [event.startDate timeIntervalSince1970];
                    NSString *intervalString = [NSString stringWithFormat:@"%f", ti];

                    [betterEvent setObject: [df stringFromDate:event.startDate] forKey:@"startDate"];
                    [betterEvent setObject: intervalString forKey:@"startDateEpoch" ];
                }

                if (event.endDate) {
                    NSTimeInterval ti = [event.endDate timeIntervalSince1970];
                    NSString *intervalString = [NSString stringWithFormat:@"%f", ti];

                    [betterEvent setObject:[df stringFromDate:event.endDate] forKey:@"endDate"];
                    [betterEvent setObject: intervalString forKey:@"endDateEpoch" ];
                }

                if (event.allDay) {
                    [betterEvent setObject:@"true" forKey:@"allDay"];
                } else {
                    [betterEvent setObject:@"false" forKey:@"allDay"];
                }

                if (event.isDetached) {
                    [betterEvent setObject:@"true" forKey:@"isDetached"];
                } else {
                    [betterEvent setObject:@"false" forKey:@"isDetached"];
                }

                if (event.organizer && [event.organizer name]) {
                    [betterEvent setObject:[event.organizer name] forKey:@"organizer"];
                }

                if (event.status) {
                    switch (event.status) {
                        case EKEventStatusConfirmed:
                            [betterEvent setObject: @"confirmed" forKey:@"status"];
                            break;
                        case EKEventStatusTentative:
                            [betterEvent setObject: @"tentative" forKey:@"status"];
                            break;
                        case EKEventStatusCanceled:
                            [betterEvent setObject: @"canceled" forKey:@"status"];
                            break;
                        default:
                            [betterEvent setObject: @"none" forKey:@"status"];
                            break;
                    }
                }

                if (event.calendar) {
                    [betterEvent setObject:[event.calendar title] forKey:@"calendar"];
                    [betterEvent setObject:[event.calendar calendarIdentifier] forKey:@"calendarIdentifier"];
                }

                if (event.title) {
                    [betterEvent setObject:event.title forKey:@"title"];
                }

                if (event.location) {
                    [betterEvent setObject:event.location forKey:@"location"];
                }

                if (event.creationDate) {
                    [betterEvent setObject:[df stringFromDate:event.creationDate] forKey:@"creationDate"];
                }

                if (event.lastModifiedDate) {
                    [betterEvent setObject:[df stringFromDate:event.lastModifiedDate] forKey:@"lastModifiedDate"];
                }

                if (event.timeZone) {
                    [betterEvent setObject:[event.timeZone abbreviation] forKey:@"timezone"];
                }

                if (event.URL) {
                    [betterEvent setObject:[event.URL absoluteString] forKey:@"URL"];
                }

                if (event.notes) {
                    [betterEvent setObject:event.notes forKey:@"message"];
                }

                if (event.attendees) {
                    NSMutableArray *betterAttendees = [NSMutableArray array];

                    for (EKParticipant *attendee in event.attendees) {
                        NSMutableDictionary * betterAttendee = [NSMutableDictionary dictionary];
                        if (attendee.name) {
                            [betterAttendee setValue:attendee.name forKey:@"name"];
                        } else {
                            [betterAttendee setValue:@"" forKey:@"name"];
                        }

                        if ([attendee URL]) {
                            [betterAttendee setValue:[[attendee URL] absoluteString] forKey:@"url"];
                        } else {
                            [betterAttendee setValue:@"" forKey:@"url"];
                        }

                        [betterAttendees addObject:betterAttendee];
                    }

                    [betterEvent setObject:betterAttendees forKey:@"attendees"];
                }

                [finalResults addObject:betterEvent];
            }

            CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:finalResults];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    }];
}


-(void)findEvent:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;

    NSDictionary* options = [command.arguments objectAtIndex:0];

    NSString* title      = [options objectForKey:@"title"];
    NSString* location   = [options objectForKey:@"location"];
    NSString* notes      = [options objectForKey:@"notes"];
    NSNumber* startTime  = [options objectForKey:@"startTime"];
    NSNumber* endTime    = [options objectForKey:@"endTime"];

    NSTimeInterval _startInterval = [startTime doubleValue] / 1000; // strip millis
    NSDate *myStartDate = [NSDate dateWithTimeIntervalSince1970:_startInterval];

    NSTimeInterval _endInterval = [endTime doubleValue] / 1000; // strip millis
    NSDate *myEndDate = [NSDate dateWithTimeIntervalSince1970:_endInterval];

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

    EKCalendar* calendar = self.eventStore.defaultCalendarForNewEvents;
    if (calendar == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No default calendar found. Is access to the Calendar blocked for this app?"];
        [self writeJavascript:[result toErrorCallbackString:command.callbackId]];
    } else {
        NSArray *matchingEvents = [self findEKEventsWithTitle:title location:location notes:notes startDate:myStartDate endDate:myEndDate calendar:calendar];

        NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:matchingEvents.count];

        // Stringify the results - Cordova can't deal with Obj-C objects
        for (EKEvent * event in matchingEvents) {
            NSMutableDictionary *entry = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                          event.title, @"title",
                                          event.location, @"location",
                                          event.notes, @"message",
                                          [df stringFromDate:event.startDate], @"startDate",
                                          [df stringFromDate:event.endDate], @"endDate", nil];
            [finalResults addObject:entry];
        }

        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsArray:finalResults];
        [self writeJavascript:[result toSuccessCallbackString:callbackId]];
    }
}


-(void)createCalendar:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* calendarName = [options objectForKey:@"calendarName"];
    NSString* hexColor = [options objectForKey:@"calendarColor"];

    EKCalendar *cal = [self findEKCalendar:calendarName];
    if (cal == nil) {
        cal = [EKCalendar calendarWithEventStore:self.eventStore];
        cal.title = calendarName;
        if (hexColor != (id)[NSNull null]) {
            UIColor *theColor = [self colorFromHexString:hexColor];
            cal.CGColor = theColor.CGColor;
        }
        cal.source = [self findEKSource];

        // if the user did not allow permission to access the calendar, the error Object will be filled
        NSError* error;
        [self.eventStore saveCalendar:cal commit:YES error:&error];
        if (error == nil) {
            NSLog(@"created calendar: %@", cal.title);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self writeJavascript:[result toSuccessCallbackString:callbackId]];
        } else {
            NSLog(@"could not create calendar, error: %@", error.description);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Calendar could not be created. Is access to the Calendar blocked for this app?"];
            [self writeJavascript:[result toErrorCallbackString:callbackId]];
        }

    } else {
        // ok, it already exists
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:@"OK, Calendar already exists"];
        [self writeJavascript:[result toSuccessCallbackString:callbackId]];
    }
}

// Assumes input like "#00FF00" (#RRGGBB)
- (UIColor *)colorFromHexString:(NSString *)hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

-(void)deleteCalendar:(CDVInvokedUrlCommand*)command {
    NSString *callbackId = command.callbackId;
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* calendarName = [options objectForKey:@"calendarName"];

    EKCalendar *thisCalendar = [self findEKCalendar:calendarName];

    if (thisCalendar == nil) {
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        [self writeJavascript:[pluginResult toErrorCallbackString:callbackId]];
    } else {
        NSError *error;
        [eventStore removeCalendar:thisCalendar commit:YES error:&error];
        if (error) {
            NSLog(@"Error in deleteCalendar: %@", error.localizedDescription);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.userInfo.description];
            [self writeJavascript:[result toErrorCallbackString:callbackId]];
        } else {
            NSLog(@"Deleted calendar: %@", thisCalendar.title);
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self writeJavascript:[result toSuccessCallbackString:callbackId]];
        }
    }
}

@end
