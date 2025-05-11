# OmegleLike Skipper

![Demo](demo/next.gif)  

OmegleLike Skipper is a tool for skipping those unwanted users on Omegle-like sites.

Here's what you can do with it:
- Use it solo to skip with the left arrow key instead of mouse clicks
- Hook it up with Videochat Extension to let it make the skip calls for you

Works like a charm anywhere you can click with your mouse!

# Installation

Grab the latest version [here](https://github.com/videochat-extension/skipper/releases).  

# Why We Built This

We all know the struggle of dealing with unwanted users on Omegle clones. Back in the day, Videochat Extension had some sweet features to handle this:
- Arrow key skips
- AI gender filtering
- Location filtering
- Blacklisting

But after getting burned three times on putting too much trust in third-party platforms, we decided to switch gears and focus on building a universal WebRTC monitoring tool instead.

A lot of people kept asking for the automation to come back, so here we are!

Once we hit enough requests and wrapped up the core features of our new extension, we dove into building OmegleLike Skipper. 

We quickly realized that making a reliable clicker for every Omegle clone wouldn't work in a browser. We needed a standalone solution that could tap into the Windows API to make clicks look natural and safely configure where to click. Additionally, it was impossible to keep track of hundreds of sites' button IDs, and we needed global arrow hotkeys, which aren't possible in a Chromium-based browser.

![Demo](demo/turnstile.gif)

We had big dreams for this thing - fancy macro sequences, presets, and super-realistic mouse movements. But after months of development headaches, we realized we were overcomplicating things. Sometimes the simplest solution is the best one - just clicking that skip button!

The biggest challenge? Making mouse movements look human turned out to be way harder than it would be to build our own omegle-like browser solving the same automation issue. The math behind natural-looking behavior is a real pain to implement.

Even though we put our nerves into making these algorithms look natural, they couldn't beat basic anti-bot systems. And any new algorithm would be a target for a model trained on its data. While these security issues are mostly theoretical, we've had some weird issues with ome.tv in the past that never got resolved. With machine learning being everywhere these days, have to be ready for anything.

Just a friendly reminder: if you're using Skipper on sites that don't play nice with mods, the risk is on you! We did everything we could to make it safe, but there is always a risk that a moderator could spot you pressing arrow keys or that we missed something. We could theoretically scale countermeasures in the event of a random mass ban-wave, but if the bans are singular, we won't be able to assist in isolated cases as we made strategic decisions to switch focus away from hostile platforms a while ago.

We got so wrapped up in the math that we kinda lost sight of the goal - just clicking a button! Lesson learned - we'll be smarter about picking our battles from now on.

In the end, we ended up with a simple clicker...

# Setup

![Demo](demo/setup.gif)

# License

This isn't open source, but we're keeping the code visible for transparency.  
Check out the full license in the installer - the build workflow has the latest version.
