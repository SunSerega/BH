unit BHFormData;

//ToDo сделать тип прогручиваемого окна, которое смогут создавать и модули, и сам BH
//Чтоб можно было делать под-меню

interface

{$define DEBUG_FAST_EXIT}

{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}
uses System.Windows.Forms;
uses System.Drawing;

{$reference BHModuleData.dll}
type BHModule=BHModuleData.BHModule;

type
  BHForm = sealed class(Form)
    
    public static f: BHForm;
    
    
    
    public constructor;
    
    
    
    public static constructor;
    
  end;
  
implementation

uses ModuleManagerData;

function GetKeyState(nVirtKey: byte): byte;
external 'User32.dll' name 'GetKeyState';

var
  temp_bmp: Bitmap;
  gr: Graphics;
  
  Pen := new Pen(Color.Empty);
  Brush := new SolidBrush(Color.Empty);
  
  fgr: Graphics;
  TraspColor := Color.FromArgb(254,255,255);

type
  ModuleScrollWheelPart = sealed class
    
    m: BHModule;
    
    constructor(m: BHModule) :=
    self.m := m;
    
  end;
  ModuleScrollWheel = static class
    
    const Rad = 350;
    const IconSz = 100;
    
    static Parts := new List<ModuleScrollWheelPart>;
    static Rot := 0.0;
    
    
    
    static procedure Init;
    begin
      Parts.Clear;
      Parts.AddRange(BHModuleData.BHModule.Modules.Select(m->new ModuleScrollWheelPart(m)));
      
      var cap := Max(3, Parts.Count+1);
      
      if Parts.Capacity <> cap then Parts.Capacity := cap;
      
    end;
    
    static procedure Redraw;
    begin
      var h_dang := Pi/Parts.Capacity;
      var _sin_h_dang := sin(h_dang);
      var icon_r := Rad * _sin_h_dang / (1 + _sin_h_dang);
      var icon_l := Rad - icon_r;
      var icon_w := icon_r*sqrt(2);
      var h_icon_w := icon_w/2;
      
      var sx := temp_bmp.Width div 2;
      var sy := temp_bmp.Height div 2;
      
      Pen.Color := Color.Black;
      Pen.Width := 3;
      var ang := -h_dang;
      for var i := 0 to Parts.Capacity-1 do
      begin
        
        gr.DrawLine(Pen, sx,sy, sx + Rad*Sin(ang), sy - Rad*Cos(ang));
        ang += h_dang;
        
        if i < Parts.Count then
          gr.DrawImage(
            Parts[i].m.Icon,
            sx + icon_l*Sin(ang) - h_icon_w,
            sy - icon_l*Cos(ang) - h_icon_w,
            icon_w,
            icon_w
          );
        ang += h_dang;
        
      end;
      
      BHForm.f.Invoke(procedure->fgr.DrawImage(temp_bmp, 0,0));
      Brush.Color := TraspColor;
      gr.FillRectangle(Brush, 0,0, temp_bmp.Width, temp_bmp.Height);
    end;
    
    static procedure Scroll(i: integer);
    begin
      Rot += i/150;
      if Rot > +Pi*2 then Rot -= +Pi*2;
      if Rot < -Pi*2 then Rot -= -Pi*2;
      Redraw;
    end;
    
  end;

constructor BHForm.Create;
begin
  
  self.ClientSize := new System.Drawing.Size(ModuleScrollWheel.Rad*2,ModuleScrollWheel.Rad*2);
  self.FormBorderStyle := System.Windows.Forms.FormBorderStyle.None;
  self.StartPosition := FormStartPosition.CenterScreen;
  
  self.BackColor := TraspColor;
  self.TransparencyKey := TraspColor;
  self.AllowTransparency := true;
  
  temp_bmp := new Bitmap(self.ClientSize.Width, self.ClientSize.Height);
  //self.ClientSize := new System.Drawing.Size(1,1);
  gr := Graphics.FromImage(temp_bmp);
  
  Brush.Color := TraspColor;
  gr.FillRectangle(Brush, 0,0, temp_bmp.Width, temp_bmp.Height);
  fgr := self.CreateGraphics;
  fgr.DrawImage(temp_bmp, 0,0);
  
  ModuleScrollWheel.Init;
  
  self.Closing += (o,e)->
  {$ifdef DEBUG_FAST_EXIT}
  if (1=integer(true)) then
    Halt else
  {$endif DEBUG_FAST_EXIT}
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
  
  self.Shown += (o,e)->
  begin
    ModuleScrollWheel.Redraw;
  end;
  
end;

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