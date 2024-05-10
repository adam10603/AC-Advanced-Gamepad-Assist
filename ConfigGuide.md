# Configuration Guide

The default settings should be ok for most people, but there are many ways to fine-tune the steering feel using the included UI app.

![UI app](https://i.imgur.com/Wd9Rr60.png)

# General

### Re-calibrate steering

When you first spawn a car, an automatic steering calibration will always take place. It lasts about a second and it ensures the assist will work as intended.

This button is for once again performing the same calibration. This shouldn't be necessary, but the option is here just in case the automatic calibration somehow fails.

___

### Enable Advanced Gamepad Assist

Enables or disables the entire assist. When disabled, Assetto Corsa's own input handling will be used without any changes.

___

### Show Presets

![Presets](https://i.imgur.com/HQFfqyB.png)

The "Show Presets" button opens a window where you can save or load presets.

Presets store all the settings in the main window, except for [Enable Advanced Gamepad Assist](#enable-advanced-gamepad-assist).

Presets DO NOT store any setting from the [Extra settings](#extra-settings) menu.

Factory presets will show up with a `*` character in their name, which means you cannot overwrite or delete them.

___

### Simplified settings

This will display a single slider that controls most settings automatically for you. The settings that this affects will appear in blue, and you won't be able to change them manually unless you disable simplified mode.

You can use this in case you find the rest of the settings overwhelming, as this gives you a simple way to control how much steering assistance you want in general. Of course adjusting settings individually gives you a lot more flexibility, but the simplified mode can get you by as well.

___

# Steering input

### Steering rate

Simply adjusts how fast the steering is. A lower rate applies more smoothing to your steering input, but going too low can feel unresponsive. Personally I'd recommend between `30%` and `60%`, but it's up to preference.

Keep in mind that keyboard steering might need a lower rate compared to controllers in order to keep the car more stable when tapping the keys.

![Steering rate](https://i.imgur.com/cPd4m0q.gif)

___

### Steering rate at speed

Adjusts how much slower or faster the steering will get as you speed up. Negative values will make the steering slower with speed, and positive values will make it faster with speed.

___

### Target slip angle

Changes what % of relative front slip the steering will target. Higher means more steering, lower means less steering. Most cars feel best around 90-95%, but you can set it higher if you want to force the car over the limit, or if you want more heat in the front tires.

Keep in mind that not all cars will adhere to this perfectly, so it's best to verify things via the [Graphs](#graphs) setting.

___

### Countersteer response

Changes how effective it is to countersteer in a slide or drift. A higher setting will make countersteering feel more responsive by allowing you to countersteer more, however, it also makes it easier to overcorrect a slide and spin the other way.

This doesn't apply to the self-steer tendency of the car, only to manual countersteer input.

___

### Dynamic steering limit

Normally the assist will try to keep the front wheels at their ideal slip angle during a turn, but this also means that the steering would wind back quite a lot if the car starts to oversteer. This setting can adjust how much the steering angle will reduce while you turn inward when the car is oversteering.

![Dynamic limit reduction](https://i.imgur.com/GKgeWUa.gif)

In the GIF above, the car starts to oversteer on corner entry, and you can see the difference in how much the steering is allowed compensate for this (despite the player fully turning inwards in both cases).

Setting this lower allows you to turn inwards more when the car steps out, letting you scrub the front tires more. On the other hand, a higher setting will limit how much you can steer into a slide in order to prevent overworking the front tires. However, setting it too high might feel too restrictive, as the assist will be allowed to override your input more.

You can see the actual reduction in steering angle in real-time with [Graphs](#graphs) set to ***Live***.

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

The damping force will counteract the car's rotational momentum. This will prevent the self-steer force from overcorrecting and result in a more stable feel. Without damping, the self-steer can make the car wobble (especially high-grip cars at high speed).

![Damping](https://i.imgur.com/RxFHzgC.gif)

The stronger you make the [Response](#response) and [Max angle](#max-angle) settings, the more damping will be needed to keep the self-steer force in check. However, too much damping can cause the car to feel numb, so as a rule of thumb I'd recommend to keep it at a similar value to the [Response](#response) setting.

Note that since v1.4 this setting makes less of a difference, but the GIF still shows the older behavior because it's easier to see the difference.

# Extra settings

Click the gear icon ⚙️ at the top of the UI app to access additional features.

![UI app settings](https://i.imgur.com/Fy7ZHoC.png)

### Graphs

You can use this to display several graphs / values to the right of the UI app window. It has three options:

 - **None** - No graphs at all.
 - **Static** - Shows how the car's self-steer force will act. You can use this to adjust the [Response](#response) and [Max angle](#max-angle) settings and see their effects.
 - **Live** - Shows the self-steer force graph as well as some additional values, all of which will be updated on the fly as you drive.

___

### Keyboard

Allows for gas, brake, and steering input from the keyboard using the keybinds that are set in AC's control settings. You can still use a controller at the same time if this is enabled.

For all the vehicle controls to work (like shifting or handbrake) you also have to enable ***Combine with keyboard*** in AC's control settings, with the ***Input method*** set to ***Gamepad***!

There are four options for this setting:
 - **Off** - Disables keyboard driving.
 - **On** - Allows keyboard driving, but with no throttle or brake assistance.
 - **On (brake help)** - Allows keyboard driving, and provides brake assistance (similar to ABS).
 - **On (gas + brake help)** - Allows keyboard driving, and provides throttle and brake assistance (similar to TCS and ABS).

Brake assistance only works if ABS is off, and throttle assistance only works if TCS is off.

These additional assists are similar to what AC would also do to keyboard input by default. They are not as effective as actual ABS or TCS, but that's by design. Since you can use these in cars that have no ABS or TCS, it would be unfair if they were as good as those systems. The goal of these is just to more or less compensate for not having analog brake or throttle on keyboard.

Also, seering input on keyboard will have a bit more smoothing compared to controller steering.

___

### Automatic clutch

Automatically controls the clutch when the engine would otherwise stall or when setting off from a standstill.

Doesn't work on cars that don't have a clutch input, such as semi-automatics. If this is the case, an on-screen message will inform you that the current car does not support a custom auto-clutch.

___

### Shifting mode

Changes how gear shifting works.

 - **Default** - No change, the default behavior of AC.
 - **Manual** - Enables custom rev-matching and clutch logic, but gear changes are still manual.
 - **Automatic** - Enables custom rev-matching and clutch logic, as well as automatic gear changes.

The ***Automatic*** mode keeps the shift-up and shift-down buttons functional too, for temporary gear overrides. This mode will read the car's power curve and calculate the optimal shifting points for each gear to achieve the best acceleration. Currently this doesn't account for the MGU-K (like in modern F1 cars), but this might be improved in the future.

To use any of the custom settings (other than ***Default***), you have to turn OFF the regular ***Automatic shifting*** option in the game's assist settings! There's no need for the built-in ***Autoblip*** option either. This is what the assist settings should look like to allow the custom modes to work:

![Assist settings](https://i.imgur.com/419eyrF.png)

When using the ***Automatic*** mode, there are two more options you can tweak:

 - **Auto-switch into cruise mode** - Automatically switches between performance driving and cruise mode based on your throttle input. The car will upshift a lot sooner when in cruise mode. You can turn this off if you only do racing, especially for rolling starts!
 - **Downshift bias** - Changes how aggressively the car downshifts when decelerating. A high value will make the car downshift basically as soon as it can, however, this can sometimes leave you very near the end of a gear when you start accelerating again.

___

### Left / right trigger feedback

This option utilizes the trigger vibrations in modern Xbox controllers. The sliders determine the strength of the vibration feedback on each trigger.

Left trigger vibrations are sent when experiencing a wheel lockup, and right trigger vibrations are sent when experiencing wheelspin. By default the left and right triggers only vibrate if ABS and TCS are turned off respectively, but the [Trigger feedback with ABS/TCS](#trigger-feedback-with-abstcs) can change this.

The vibration feedback has two steps: a light vibration when approaching the limit, and a stronger vibration when going over the limit.

___

### Trigger feedback with ABS/TCS

This setting allows the Xbox trigger vibrations to work even when ABS or TCS are enabled. Without this option you'd only get vibrations in each trigger if the respective assist is turned off.

___

### Factory reset

Resets every setting to its default value and deletes all presets.

You have to click it twice to confirm.

___

### Gamma

Controls AC's own ***Steering gamma*** setting.

Higher gamma means your analog stick becomes less sensitive near the center. Personally I use `135%`, but it's up to preference.

___

### Deadzone

Controls AC's own ***Steering deadzone*** setting.

Set it just high enough so that the steering is always centered when you're not touching the stick.

___

### Rumble

Controls AC's own ***Rumble effects*** setting.