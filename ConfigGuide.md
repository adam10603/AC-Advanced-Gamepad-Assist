# Configuration Guide

The default settings should be ok for most people, but there are many ways to fine-tune the steering feel using the included UI app.

![UI app](https://i.imgur.com/f78dwtc.png)

# General

### Re-calibrate steering

When you first spawn a car, an automatic steering calibration will always take place. It lasts about a second and it ensures the assist will work as intended.

This button is for once again performing the same calibration. It shouldn't be necessary (since the automatic calibration happens anyway), but I left the option here just in case the automatic calibration somehow fails.

Although this shouldn't happen, but in case you notice the steering angle being noticeably higher or lower than it should be, you might want to stop and re-calibrate the steering.

___

### Graphs

You can use this to display several graphs / values to the right of the UI app window. It has three options:

 - **None** - No graphs at all.
 - **Static** - Shows how the car's self-steer force will act. You can use this to adjust the [Response](#response) and [Max angle](#max-angle) settings and see their effects.
 - **Live** - Shows the self-steer force graph as well as some additional values, all of which will be updated on the fly as you drive.

___

### Enable Advanced Gamepad Assist

Enables or disables the entire assist. When disabled, Assetto Corsa's own input handling will be used without any changes.

___

### Keyboard

Allows for gas, brake, and steering input from the keyboard using the keybinds that are set in AC's control settings. You can still use a controller at the same time if this is enabled.

For all the vehicle controls to work (like shifting or handbrake) you also have to enable ***Combine with keyboard*** in AC's control settings!

There are four options for this setting:
 - **Off** - Disables keyboard driving.
 - **On** - Allows keyboard driving, but with no throttle or brake assistance.
 - **On (brake help)** - Allows keyboard driving, and provides brake assistance (similar to ABS).
 - **On (gas + brake help)** - Allows keyboard driving, and provides throttle and brake assistance (similar to TCS and ABS).

Brake assistance only works if ABS is off, and throttle assistance only works if TCS is off.

These additional assists are similar to what AC would also do to keyboard input. They are not as effective as actual ABS or TCS, but that's by design. Since you can use these in cars that have no ABS or TCS, it would be unfair if they were as good as those systems. The goal of these is just to more or less compensate for not having analog brake or throttle on keyboard.

Steering input on keyboard will have a bit more smoothing compared to controller steering.

___

### Simplified settings

This will display a single slider that controls most settings automatically for you. The settings that this affects will appear in blue, and you won't be able to change them manually unless you disable simplified mode.

You can use this in case you find the rest of the settings overwhelming, as this gives you a simple way to control how much steering assistance you want in general. Of course adjusting settings individually gives you a lot more flexibility, but the simplified mode will get you by if you don't feel like doing that.

___

# Steering input

### Steering rate

Simply adjusts how fast the steering is.

![Steering rate](https://i.imgur.com/cPd4m0q.gif)

___

### Steering rate at speed

Adjusts how much slower or faster the steering will get as you speed up. Negative values will make the steering slower with speed, and positive values will make it faster with speed.

___

### Countersteer response

Changes how effective it is to countersteer in a slide or drift. A higher setting will make countersteering feel more responsive by allowing you to countersteer more, however, it also makes it easier to overcorrect a slide and spin the other way.

This doesn't apply to the self-steer tendency of the car, only to manual countersteer input.

___

### Dynamic limit reduction

Normally the assist will try to keep the front wheels at their ideal slip angle during a turn, but this also means that the steering would wind back quite a lot if the car starts to oversteer. This setting will limit how much the steering angle can reduce while you turn inward when the car is oversteering.

![Dynamic limit reduction](https://i.imgur.com/BicDQ7Q.gif)

In the GIF above, the car starts to oversteer on corner entry, and you can see the difference in how much the steering is allowed compensate for this (despite the player fully turning inwards in both cases).

Setting this too low makes it easier to steer more than required, especially during a harsh corner entry. A higher value will allow the steering to reduce more in order to maintain the best front slip angle. However, setting it too high might feel a bit too inconsistent and restrictive, as the assist will be allowed to override your input more.

For maintaining the best front grip, this should be at least as high as the travel angle in a typical turn (which you can see with [Graphs](#graphs) set to ***Live***). Around `5°` is enough for that in the majority of cars. But if you like the feeling of getting some front wheel slippage when you throw the car into a turn, then you can set it lower. Note that with `0°` you'll pretty much always steer more than required when you give full input.

___

# Self-steer force

### Response

This adjusts how aggressive the car's self-steer force is (before reaching its [Max angle](#max-angle) cap). Higher values will make it fight harder to keep the car straight and prevent it from oversteering. Lower values will make the self-steer more lazy, and less able to stabilize the car, resulting in a looser driving feel overall.

![Response](https://i.imgur.com/BwBzxmE.gif)

Note that the self-steer force has less of an effect the more input you give, so this is most noticeable when you don't give any input and just let the car stabilize itself. In the GIF above, the difference only shows once the player releases the steering.

If you enable [Graphs](#graphs), you can see how the self-steer behavior changes as you adjust this setting.

___

### Max angle

Limits the car's self-steer ability. This means that regardless of the [Response](#response) setting, the car's self-steer will not be able to reach a higher steering angle than this. Higher values here will make the self-steer force able to countersteer to a bigger extent.

![Max angle](https://i.imgur.com/2kDS7je.gif)

In the GIF above, the player forces the car into a slide then releases the steering.

If you enable [Graphs](#graphs), you can see how the self-steer behavior changes as you adjust this setting.

As a sidenote for drifters, if you crank this setting to `90°` and play around with the [Response](#response) setting, you can get the assist to automatically hold a certain drift angle for you, if that's your thing.

___

### Damping

The damping force is what prevents the self-steer force from overcorrecting. Without damping, the self-steer can make the car wobble (especially high-grip cars at high speed).

![Damping](https://i.imgur.com/RxFHzgC.gif)

The stronger you make the [Response](#response) and [Max angle](#max-angle) settings, the more damping will be needed to keep the self-steer force in check. However, too much damping can cause things to feel a bit off, so as a rule of thumb I'd recommend to keep it at a similar value to the [Response](#response) setting.