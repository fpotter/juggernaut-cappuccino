/*
 * JuggernautController.j
 *
 * Created by Fred Potter on November 11, 2010.
 * 
 * The MIT License
 * 
 * Copyright (c) 2010 Fred Potter
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 */

@import <Foundation/Foundation.j>

JuggernautDidReceiveMesssageNotification = @"JuggernautDidReceiveMesssageNotification";

var SharedJuggernautController = nil,
    JuggernautHasLoadedScript = NO;

@implementation JuggernautController : CPObject
{
    CPString _host;
    int _port;
    
    JSObject _jug;
    CPArray _queue;
    
    CPArray _subscriptions;
}

+ (void)sharedController
{
    if (!SharedJuggernautController)
    {
        SharedJuggernautController = [[self alloc] init];
    }

    return SharedJuggernautController;
}

- (void)init
{
    if (self = [super init])
    {
        _jug = nil;
        _queue = [];
        _subscriptions = [];
    }
    return self;
}

- (void)connectToHost:(CPString)host port:(int)port
{
    if (JuggernautHasLoadedScript)
    {
        [CPException raise:CPInternalInconsistencyException reason:"You can only connect once."];
        return;
    }
    
    _host = host;
    _port = port;
    
    var script = document.createElement("script");
    script.src = "http://" + _host + ":" + _port + "/application.js";
    script.type = "text/javascript";
    script.charset = "UTF-8";
    document.getElementsByTagName("head")[0].appendChild(script);
    
    JuggernautHasLoadedScript = YES;
    
    // Either one or the other of the following handlers will get
    // called, depending on the browser.
    
    script.onreadystatechange = function () {
        if (this.readyState == 'complete')
        {
            [self onScriptLoaded];
        }
    };
    
    script.onload = function()
    {
        [self onScriptLoaded];
    };
}

- (void)onScriptLoaded
{
    _jug = new Juggernaut({
        host : _host,
        port : _port
    });

    _jug.on("connect", function()
    {
        CPLog.info("Juggernaut connected");
    });

    _jug.on("disconnect", function()
    {
        CPLog.info("Juggernaut disconnected.")
    });

    _jug.on("reconnect", function()
    {
        CPLog.info("Juggernaut reconnecting.")
    });
    
    CPLog.info("Juggernaut loaded & initialized.");
    
    // If any work got queued up while we were waiting
    // for the script to load...
    for (var i = 0; i < [_queue count]; i++)
    {
        var func = _queue[i];
        func();
    }
    
    [_queue removeAllObjects];
}

- (void)subscribe:(CPString)channel
{
    var doSubscribe = function()
    {
        CPLog.info("Juggernaut subscribing to " + channel + " ...");
        _jug.subscribe(channel, function(data)
        {
            CPLog.info("Juggernaut received from " + channel + ": " + [data substringWithRange:CPMakeRange(0, MIN([data length], 50))] + " ...");
            
            var dict = [CPDictionary dictionaryWithJSObject:[data objectFromJSON]];
            
            var userInfo = [CPDictionary dictionaryWithObjectsAndKeys:
                            channel,
                            "channel"];
            
            [[CPNotificationCenter defaultCenter] postNotificationName:JuggernautDidReceiveMesssageNotification
                                                                object:dict
                                                              userInfo:userInfo];
        });
        
        [_subscriptions addObject:channel];
    };
    
    if (_jug == nil)
    {
        // The script must still be loading - lets just queue this for later
        [_queue addObject:doSubscribe];
    }
    else
    {
        doSubscribe();
    }
}

- (void)unsubscribe:(CPString)channel
{
    var doUnsubscribe = function()
    {
        CPLog.info("Juggernaut unsubscribing from " + channel + " ...");
        _jug.unsubscribe(channel);
        
        [_subscriptions removeObject:channel];
    };
    
    if (_jug == nil)
    {
        // The script must still be loading - lets just queue this for later
        [_queue addObject:doUnsubscribe];
    }
    else
    {
        doUnsubscribe();
    }
}

- (void)unsubscribeAll
{
    _subscriptions.forEach(function(channel)
    {
        [self unsubscribe:channel];
    });
}

@end