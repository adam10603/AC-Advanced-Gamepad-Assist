# Assetto Corsa: Advanced Gamepad Assist

![Version](https://img.shields.io/badge/Version-1.1-blue.svg) ![Compatibility](https://img.shields.io/badge/CSP-0.1.79-green.svg)

![Banner](https://i.imgur.com/AiZvIHx.png)

## 🖊️ Intro

This is a mod for Assetto Corsa that provides a steering assist system for players on controller or keyboard. It aims for improved steering feel and car control, while being highly customizable. It's suitable for all driving styles including racing, drifting etc., and it's recommended to anyone on controller or keyboard regardless of skill level.

It works in single player as well as on any online server.

The main features of this mod include:

 - Accurate steering limit, based on the optimal slip angle of the font tires
 - Self-steer tendency that mimics the effects of the car's caster angle and helps with stability
 - Allowing both keyboard and controller input while using the assist
 - Highly customizable settings through a UI app
 - Real-time readouts of tire slip and more through the UI app

## 📖 Why?

There are a number of Gamepad FX scripts for Assetto Corsa out there that target the same issues with controller / keyboard input. However, assists like this are quite the task to get right, and even full-time game developers often don't really nail it in their driving games. But the fact that there are so many other AC mods to solve this issue (and some are very popular) clearly shows that there's demand for this kind of thing.

My biggest problem with most other assists I found is they simply take the force-feedback value from AC and slap it onto your input in one way or another. This might sound fine at first considering that the goal is overcoming the lack of FFB, but in practice doing it that way has a number of drawbacks, since the game's FFB force was never meant for this purpose. There are other ways of achieving a similar effect that are much better suited for non-FFB input devices.

As to why assists like this are needed in general, that boils down to overcoming the limitations that come from the lack of FFB and the small or no analog movement range. I've made a similar mod for BeamNG.drive before, and on the Github repo of that mod I have a longer page with the reasoning behind assists like this. [You can read that page here](https://github.com/adam10603/BeamNG-Advanced-Steering/blob/release/Explanation.md) if you're interested.

## 🖥️ Installation

This mod requires [***Content Manager***](https://assettocorsa.club/content-manager.html) and [***Custom Shaders Patch***](https://acstuff.ru/patch/) to be installed!

First, download the latest version from [***Releases***](https://github.com/adam10603/AC-Advanced-Gamepad-Assist/releases) or from [***RaceDepartment***](https://www.racedepartment.com/downloads/advanced-gamepad-assist.62485/).

You can install the mod in two ways:

#### If you have the lite (free) version of Content Manager:

 - Open the `Advanced Gamepad Assist` folder, and copy the `apps` and `extension` folders.
 - Paste the two folders into your main `assettocorsa` folder.

#### If you own the full (paid) version of Content Manager:

 - Copy the `Advanced Gamepad Assist` folder, and paste it inside the `assettocorsa/mods` folder.
   - If you don't see the `mods` folder then create it.
 - Open ***Content Manager***, go to ***Content*** on the upper right, then to ***Mods*** on the upper left.
 - Make sure that ***Advanced Gamepad Assist*** is enabled (should be on the right side).

## 🛠 Setup

 - Open ***Content Manager***, go to ***Settings*** on the upper right, then ***Custom Shaders Patch*** on the upper left, and ***Gamepad FX*** on the left.
 - Make sure ***Active*** is checked, and select the ***Advanced Gamepad Assist*** script.

That's pretty much it, the assist should be working now.

In AC's own control settings, you can set the ***Steering gamma***, ***Steering deadzone*** and ***Rumble effects*** sliders to your liking, but the other sliders won't change anything while using this assist. Below you can see the ones that don't matter crossed out with red:

![Control settings](https://i.imgur.com/rP0NoyC.png)

Beyond this, any further configuration is done through the UI app in-game.

## 🎮 Usage

When you first start driving a car, a quick steering calibration will take place to ensure the assist can work properly. You won't be able to drive while this is happening, but it only lasts a second or so.

If you want to tweak the steering feel, you can add the UI app called ***Advanced Gamepad Assist Config*** from the side menu in-game.

![Adding the UI app](https://i.imgur.com/Ffms6Rd.png)

**[📝 Click here](ConfigGuide.md) for a detailed breakdown of all the settings in the UI app!**

## 💖 Supporting

This project is freely available, but if you wish to support its development then you can use the 💟 button at the top to do so, or the links under the ***Sponsor this project*** section.

___

###### © 2023 Adam D., license: MIT