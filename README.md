# Assetto Corsa: Advanced Gamepad Assist

![Version](https://img.shields.io/badge/Version-1.0-blue.svg) ![Compatibility](https://img.shields.io/badge/CSP-0.1.79-green.svg)

![Banner](https://i.imgur.com/AiZvIHx.png)

## 🖊️ Intro

This is a mod for Assetto Corsa that provides a steering assist system for players who use a controller. It aims for improved steering feel and car control, while being highly customizable. It's suitable for all driving styles including racing, drifting etc., and it's recommended to anyone on a controller regardless of skill level.

It works in single player as well as on any online server you can think of.

The main features of this mod include:

 - Accurate steering limit, based on the optimal slip angle of the font tires
 - Self-steer tendency that mimics the effects of the car's caster angle and greatly helps with stability
 - Highly customizable settings through a UI app, so you can dial in the steering feel you prefer
 - Real-time readouts of tire slip and more through the UI app

## 📖 Why?

There are a number of Gamepad FX scripts for Assetto Corsa out there that target the same issues with controller driving. However, assists like this are quite the task to get right, and even full-time game developers often don't really nail it in their driving games. But the fact that there are so many other AC mods to solve this issue (and some are very popular) clearly shows that there's demand for this kind of thing.

My biggest problem with most other assists I found is they simply take the force-feedback value from AC and slap it onto your input in one way or another. This might sound fine at first considering that the goal is overcoming the lack of FFB, but in practice doing it that way has a number of drawbacks, since the game's FFB force was never meant for this purpose. There are better ways of achieving a similar effect that are more suited for controller driving.

As to why assists like this are needed in general, that boils down to overcoming the limitations of a controller due to the lack of FFB and the small analog movement range. I've made a similar mod for BeamNG.drive before, and on the Github repo of that mod I have a longer page with the reasoning behind controller assists like this. [You can read that page here](https://github.com/adam10603/BeamNG-Advanced-Steering/blob/release/Explanation.md) if you're interested.

## 🖥️ Installation

This mod requires [***Content Manager***](https://assettocorsa.club/content-manager.html) and [***Custom Shaders Patch***](https://acstuff.ru/patch/) to be installed!

First, download the latest version of the mod from the [***Releases***](https://github.com/adam10603/AC-Advanced-Gamepad-Assist/releases) section.

> If you have a previous version of this mod installed, it's a good idea to remove that first. You can remove it by deleting the following folders:
>  - `assettocorsa/apps/lua/Advanced Gamepad Assist Config`
>  - `assettocorsa/extension/lua/joypad-assist/Advanced Gamepad Assist`
>  - `assettocorsa/mods/Advanced Gamepad Assist`

You can install the mod in two ways:

#### If you own the full (paid) version of Content Manager:

 - Copy the `Advanced Gamepad Assist` folder, and paste it inside the `assettocorsa/mods` folder.
   - If you don't see the `mods` folder then create it by hand.
 - Open ***Content Manager***, go to ***Content*** on the upper right, then click on ***Mods*** on the upper left.
 - Make sure that ***Advanced Gamepad Assist*** is enabled (should be on the right side).

#### If you have the lite (free) version of Content Manager:

 - Open the `Advanced Gamepad Assist` folder, and copy the two folders that are inside (`apps` and `extension`).
 - Go to your main `assettocorsa` folder and paste the two folders you copied.

## 🛠 Setup

 - Open ***Content Manager***, and go to ***Settings*** on the upper right, then click ***Gamepad FX*** on the left side.
 - Make sure ***Active*** is checked, and select the ***Advanced Gamepad Assist*** script.

That's pretty much it, the assist should be working now.

As far as the sliders in Assetto Corsa's own control settings go, only the ***Steering gamma***, ***Steering deadzone*** and ***Rumble effects*** sliders will be active. The other sliders won't change anything while using this assist. Below you can see the ones that don't matter crossed out with red:

![Control settings](https://i.imgur.com/rP0NoyC.png)

Feel free to set up the remaining control settings according to your preference. Beyond this, any further configuration is done through the UI app in-game.

## 🎮 Usage

When you first start driving a car, a quick steering calibration will take place to ensure the assist can work properly. You won't be able to drive while this is happening, but it only lasts a second or so.

If you want to tweak the steering feel, you can that through the in-game UI app called ***Advanced Gamepad Assist Config***. You can add it to your UI through the apps menu in the top right corner.

![Adding the UI app](https://i.imgur.com/Ffms6Rd.png)

**[📝 Click here](ConfigGuide.md) for a detailed breakdown of all the settings in the UI app!**

## 💖 Supporting

This project is freely available, but if you wish to support its development then you can use the 💟 button at the top to do so, or the links under the ***Sponsor this project*** section.

___

###### © 2023 Adam D., license: MIT