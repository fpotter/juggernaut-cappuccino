# Cappuccino wrapper for Juggernaut

This is a light wrapper around [Juggernaut](https://github.com/maccman/juggernaut)'s regular Javascript API to make it a little more Cappuccino-like.

## Usage

Import...

    @import "JuggernautController.j"

You connect and subscribe...

    // connecting will automatically load application.js from http://yourHost:yourPort/application.js
    [[JuggernautController sharedController] connectToHost:"localhost" port:8080];
    
    [[JuggernautController sharedController] subscribe:"some-channel"];

Register for messages...

    [[CPNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMessage:)
                                                 name:JuggernautDidReceiveMesssageNotification
                                               object:nil];

And, handle messages...

    - (void)didReceiveMessage:(CPNotification)notification
    {
        var jsonObject = [notification object];
        var channel = [[notification userInfo] objectForKey:"channel"];

        CPLog.info("Received " + jsonObject + " on channel " + channel);
    }
