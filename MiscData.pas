unit MiscData;

interface

procedure ShowCriticalError(e: Exception; title: string);

implementation

{$reference System.Windows.Forms.dll}
uses System.Windows.Forms;

procedure TryShowMB(s1, s2: string) :=
MessageBox.Show(s2, s1);

procedure TrySaveLog(s1, s2: string);
begin
  var fname := 'Critical Error.txt';
  WriteAllText(fname, Concat(s1, ':'#10#10, s2));
  Exec(fname);
end;


function GetText1(e: Exception) := _ObjectToString(e);
function GetText2(e: Exception) := e.Message+#10'*error getting full error text*';
function GetText3(e: Exception) := '*error geting error text*';


procedure ShowCriticalError(e: Exception; title: string);
begin
  var text: string;
  
  foreach var gtf in Arr(GetText1, GetText2, GetText3) do
  try
    text := gtf(e);
    break;
  except
  end;
  
  foreach var sm in Arr(TryShowMB, TrySaveLog) do
  try
    sm(title, text);
    break;
  except
  end;
  
  Halt;
end;

end.