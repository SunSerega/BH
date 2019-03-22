
Background Helper - program designed to do background stuff fast, without worrying you.

You don't need to use pascal to make modules. You can use any .Net language, like C#.

Here are some screenshots:\
*coming soon*

<details>
<summary>
How to modules
</summary>

BHModules are different paths of BH that can do stuff.\
From programming perspective - they are managed classes in .Net .dll file.

To create BHModule - you need to create folder in "Modules" folder.\
And in it - create .dll in any .Net language (like C#, i am, personally, using PascalABC.Net)

All classes derived from BHModule (it's in `BHModuleData.dll`),\
that have constructor without parameters - would turn into BHModules.

You can have multiple .dll's in 1 folder\
and multiple modules in 1 .dll,\
but it's not advised.

Any BHModule MUST override:

- method StartUp - executed every time module turn's on
- method ShutDown - executed every time module turn's off
- property Name - unique name

---
</details>

If something goes horribly wrong - press B + H + Esc, it would halt BH process in no more than 200ms
