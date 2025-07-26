//
//  SharedMacros.m
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 10.02.25.
//

#pragma mark - vardesc macro

NSString *_Nullable __vardesc(NSString *_Nonnull keys_commaSeparated, id _Nullable __strong *_Nonnull values, size_t count, bool linebreaks) {
    
    /// Helper for the `vardesc` and `vardescl` macros
    
    NSArray *keys = [keys_commaSeparated componentsSeparatedByString: @","];
    
    if (count != keys.count) {
        assert(false && "vardesc: Number of keys and values is not equal - This is likely due to one of the passed-in expressions containing a comma.");
        return nil;
    }
    
    NSMutableString *result = [NSMutableString string];
    
    [result appendString: linebreaks ? @"{\n    " : @"{ "];
    for (NSUInteger i = 0; i < count; i++) {
        if (i) [result appendString: linebreaks ? @"\n    " : @" | "];
        [result appendFormat: @"%@ = %@", [keys[i] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]], values[i]];
    }
    [result appendString: linebreaks ? @"\n}" : @" }"];
    
    return result;
}
