# godot_task_server
Task Server for running background computations in paraller threads. A Task pool of sorts.

### Features:
* On the fly changeable thread pool size
* Automatic: Add as an plugin and a TaskServer starts in the background automatically
* Simple: Just add TaskServerClient node to your object and post tasks from your nodes gdscript
* Optionally either provide own function to execute OR extend TaskServerWorkItem for more functionality
* Custom task priorities per work item
* Godot Editor UI extensions

## Usage
copy contents of this repo into your godot project /addons/godot_task_server folder

OR

Start a git bash into addons directory and create a submodule
```
git submodule add git@github.com:kupoli/godot_task_server.git
```

## Documentation

Documentation can be found in the wiki:

https://github.com/kupoli/godot_task_server/wiki

## Examples

Example Godot project:

https://github.com/kupoli/godot_task_server-examples


## Tested with

Godot 3.4.2
