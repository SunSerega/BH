unit BHFormData;

interface

{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}
uses System.Windows.Forms;
uses System.Drawing;

type
  BHForm = class(Form)
    
    public static f: BHForm;
    
    public 
    
    
    
    public constructor;
    begin
      
      self.Closing += (o,e)->
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
      
    end;
    
    
    
    public static constructor :=
    f := new BHForm;
    
  end;
  
implementation

uses ModuleManagerData;

end.