unit BHFormData;
//ToDo не компилируется, скорее всего баг компилятора

//ToDo try-except в статичные конструкторы

//ToDo проверить issue:
// - #1575

interface

{$define DEBUG_FAST_EXIT}

{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}
uses System.Windows.Forms;
uses System.Drawing;

{$reference BHModuleData.dll}

//ToDo #1575
type
  BHModule=BHModuleData.BHModule;
  
  Image = BHModuleData.Image;
  Painter = BHModuleData.Painter;
  
  MenuBase = BHModuleData.MenuBase;
  Menu<T> = BHModuleData.Menu<T>;
  
  CircleMenuData = BHModuleData.CircleMenuData;
  CircleMenu = BHModuleData.CircleMenu;
  
  
  
  ModuleScrollWheel = class(CircleMenu)
    static WSz := Min(Screen.PrimaryScreen.WorkingArea.Width, Screen.PrimaryScreen.WorkingArea.Height);
    
    constructor;
    begin
      inherited Create(WSz*0.8, WSz*0.24);
      
      foreach var m in BHModuleData.BHModule.Modules do
        AddMenu(m.Menu, m.Icon, m.BackColor);
      
      self.Seal;
    end;
    
  end;
  
  
  
  BHForm = sealed class(Form)
    
    public static f: BHForm;
    public MainBHMenu: ModuleScrollWheel;
    
    
    
    public constructor;
    
    public procedure Redraw;
    
    
    
    public static constructor;
    
  end;
  
implementation

uses ModuleManagerData;

procedure CycledCall(tps: real; proc: Action0);
begin
  var span := System.TimeSpan.FromSeconds(1/tps);
  var max_catch_up := System.TimeSpan.FromSeconds(3/tps);
  var LT := DateTime.Now;
  
  while true do
  begin
    
    proc;
    
    LT := LT+span;
    var CT := DateTime.Now;
    if CT<LT then
      System.Threading.Thread.Sleep(LT-CT) else
    if CT-LT>max_catch_up then
      LT := CT - max_catch_up
    
  end;
  
end;

constructor BHForm.Create;
begin
  MainBHMenu := new ModuleScrollWheel;
  
  self.FormBorderStyle := System.Windows.Forms.FormBorderStyle.None;
  self.StartPosition := FormStartPosition.CenterScreen;
  
  self.Closing += (o,e)->
  {$ifdef DEBUG_FAST_EXIT}
  Halt();
  {$else DEBUG_FAST_EXIT}
  if f<>nil then
    case MessageBox.Show(
      
      $'This way of closing window going to kill process of BH.{#10}' +
      $'If you want hide window - run one more BH.exe on top of this one.{#10}' +
      $'Do you still want to exit BH?',
      
      $'Exit BH?',
      
      MessageBoxButtons.YesNo
    ) of
      System.Windows.Forms.DialogResult.Yes: Halt;
      else e.Cancel := true;
    end;
  {$endif DEBUG_FAST_EXIT}
  
  self.Load += (o,e)->
  begin
    tick_thr := System.Threading.Thread.Create(()->CycledCall(60, MenuBase.GTickCurrent));
    
    var FW := Ceil(self.MainBHMenu.R*2)+1;
    
    self.ClientSize := new System.Drawing.Size(FW,FW);
    var buff := new Bitmap(FW,FW);
    
    var gr := self.CreateGraphics;
    var pnt := new Painter(buff);
    
    redraw_thr := System.Threading.Thread.Create(()->CycledCall(60, ()->
    begin
      
      pnt.FillWhite;
      MenuBase.DrawCurrent(pnt);
      
      pnt.Dispose;
      gr.DrawImage(buff, 0,0);
      pnt := new Painter(buff);
    end));
    
    gr.FillRectangle(new SolidBrush(Color.White), 0,0, FW,FW);
    
    redraw_thr.Start;
    tick_thr.Start;
  end;
  
end;

function GetKeyState(nVirtKey: byte): byte;
external 'User32.dll' name 'GetKeyState';

static constructor BHForm.Create;
begin
  f := new BHForm;
  
  var exit_keys := Arr($42, $48, $1B);//B + H + Esc
  System.Threading.Thread.Create(()->
  while true do
  begin
    if exit_keys.All(k->GetKeyState(k) shr 7 = $1) then Halt;
    Sleep(200);
  end).Start;
  
end;

end.