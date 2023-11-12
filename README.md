# k3d

k3d is a modified version of [groveburger's g3d](https://github.com/groverburger/g3d) for use with the deltarune fangame engine [Kristal](https://github.com/KristalTeam/Kristal). It allows for the rendering of simple 3d models ease.
![enter image description here](https://file.garden/ZP_yEdRM-w48DhO4/deltarun3.gif)
## Features
* 3d models both in battle and in the overworld
* Seamless model rendering into the 2d world 
* Models can move, rotate, and more, all using familiar api
* Minimal continuous performance issues
* As well as...
## Tiled Integration
k3d is fully compatible with Tiled and the format Kristal uses to load maps, and loading a model into the world is made easy:
![k3d tiled integration](https://file.garden/ZP_yEdRM-w48DhO4/howtomonkee.png)Create a `Model` in the `objects` layer, with the path being the location of your model in `assets/model`, and the texture being an image file that the model will use, also in `assets/model`:
![models folder structure](https://file.garden/ZP_yEdRM-w48DhO4/foldermonkee.png)That's it!![enter image description here](https://file.garden/ZP_yEdRM-w48DhO4/monkee.png)

## Please Note
k3d is in a very early state and as such, is very buggy. the api provided  is not fixed and is bound to change on updates (partially why it is not yet listed here), potentially breaking previous scripts. If you need assistance, please ask in the [k3d discord thread](link) on the kristal server. PR and any contributions are highly encouraged and welcomed!

### todo:
* better animation support
* support for actors / actorsprites
* tutorial on how to use k3d
### known issues:
* slow load times on complex collada objects
* issues loading waveform obj files
