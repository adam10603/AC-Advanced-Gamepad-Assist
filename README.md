# Assetto Corsa: Advanced Gamepad Assist

![Version](https://img.shields.io/badge/Version-1.5.2-blue.svg) ![Compatibility](https://img.shields.io/badge/CSP-0.2.0+-green.svg)

![Banner](https://i.imgur.com/AiZvIHx.png)

## 🖊️ Intro

This is a mod for Assetto Corsa that provides a custom input system for players on controller or keyboard. It aims for improved steering feel and car control, while being highly customizable. It's suitable for all driving styles including racing, drifting etc., and it's recommended to anyone on controller or keyboard regardless of skill level.

It works in single player as well as on any online server.

The main features of this mod include:

 - Accurate steering limit, based on the optimal slip angle of the font tires
 - Self-steer tendency that mimics the effects of the car's caster angle and helps with stability
 - Allows for keyboard and controller driving at the same time
 - Custom auto-clutch and automatic shifting algorithms, plus controller vibration options
 - Highly customizable settings through a UI app
 - Real-time readouts of tire slip and more

## 📖 Why?

Many driving games (including AC) are sadly lacking when it comes to controller input feel. Yes, you can technically drive with a controller in AC without any mods, but it's far from ideal. The steering feels very twitchy and nearly impossible to control, which isn't a skill issue, it's just that the game doesn't do a good job at translating controller inputs to the car. It doesn't have to be like this though, and this is where mods like this one come in.

In general, it's mostly about overcoming the limitations that come from the lack of FFB and the small or no analog movement range. I've made a similar mod for BeamNG.drive before, and on the Github repo of that mod I have a longer page with the reasoning behind assists like this. [You can read that page here](https://github.com/adam10603/BeamNG-Advanced-Steering/blob/release/Explanation.md) if you're interested.

## 🖥️ Installation

This mod requires [***Content Manager***](https://assettocorsa.club/content-manager.html) and [***Custom Shaders Patch***](https://acstuff.ru/patch/) to be installed!

First, download the latest version from [***Releases***](https://github.com/adam10603/AC-Advanced-Gamepad-Assist/releases) or from [***Overtake***](https://www.overtake.gg/downloads/advanced-gamepad-assist.62485/).

**DO NOT just drag the zip file into Content Manager** like usual, unfortunately that doesn't install it correctly.

#### To install the mod:

 - Open the `Advanced Gamepad Assist` folder, and copy the `apps` and `extension` folders.
 - Paste the two folders into your main `assettocorsa` folder.

![Installation](https://i.imgur.com/FjAcBk9.png)

Optionally, if you have the full (paid) version of Content Manager and you know how to use the `mods` folder, you can install it there instead too.

## 🛠 Setup

 - Open ***Content Manager***, go to ***Settings*** on the upper right, then ***Custom Shaders Patch*** on the upper left, and ***Gamepad FX*** on the left.
 - Make sure ***Active*** is checked under ***Gamepad Script***, and select the ***Advanced Gamepad Assist*** script.
 - Now go to ***Settings*** on the upper right, ***Assetto Corsa*** on the upper left, then ***Controls*** on the left.
 - Here make sure the ***Input Method*** is set to ***Gamepad***.

When it comes to AC's built-in steering settings, you don't need to worry about them. They either don't make a difference when using this mod, or the ones that do can be adjusted through the in-game UI app anyway.

If you want to drive on keyboard, set up the binds for it in AC's control settings, then set the ***Input method*** to ***Gamepad*** and check the ***Combine with keyboard*** option. You'll also have to enable keyboard input in the in-game UI app.

If you want to use trigger vibration (and your controller supports it), you might have to disable Steam input. You can do this if you right click AC in Steam, then go to ***Properties***, ***Controller***.

When the mod is installed and used for the first time, it automatically sets some of AC's steering settings to reasonable defaults. Specifically, it sets the steering gamma to 140%, deadzone to 12%, and rumble effects to 0%. Of course you can tweak these settings any time from the UI app, these defaults are just there for a good out-of-the-box experience that should work for most people.

## 🎮 Usage

When you first start driving a car, a quick steering calibration will take place. You won't be able to drive while this is happening, but it only lasts a second or so.

If you want to tweak the steering feel (and more) on the fly, you can add the UI app called ***Advanced Gamepad Assist Config*** from the side menu in-game.

![Adding the UI app](https://i.imgur.com/Ffms6Rd.png)

**[📝 Click here](ConfigGuide.md) for a detailed breakdown of all the settings in the UI app!**

## 💖 Supporting

This project is freely available, but if you wish to support its development then you can use the 💟 button at the top to do so, or the links under the ***Sponsor this project*** section.

___

###### © 2023 Adam D., license: MIT