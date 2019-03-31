unit MenuData;

//ToDo открытие CircleMenu должно быть менятся, если Owner имеет известный тип. К примеру для CircleMenu - это должно быть разворачивание
//ToDo не выполнять Seal если оно уже начато. Но и сбрасывать прогресс если что то в меню было отредактированно
//ToDo из Seal вызывать Seal под-меню
//ToDo отменять открытие CircleMenu если в нём 0 под-меню

uses GData;
uses MiscData;

//ToDo проверить issue
// - #1880
// - #1881
// - #1890

type
  MenuNotSealedException = class(Exception)
    
    constructor :=
    inherited Create('You need to call .Seal on menu before it can be drawn');
    
  end;
  
  ///Base type of Menu<MenuDataT>
  MenuBase = abstract class
    
    protected _owner, curr_child: MenuBase;
    protected oc_progress, oc_prog_dir: integer;
    protected static curr_menu: MenuBase;
    
    
    
    public property Owner: MenuBase read _owner;
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); abstract;
    
    ///Starts anync caching of drawable parts of menu
    ///You need to call this before menu would be drawn
    public procedure Seal; abstract;
    
    
    
    public static procedure GTickCurrent;
    
    public static procedure DrawCurrent(pnt: Painter);
    
    public static event UnProcessedEsc: procedure;
    
  end;
  
  ///BH Menu type
  Menu<SubMenuDataT> = abstract class(MenuBase)
    
    protected sub_menus := new List<(MenuBase, SubMenuDataT)>;
    
    public procedure AddMenu(m: MenuBase; data: SubMenuDataT) :=
    sub_menus.Add((m, data));
    
    public procedure RemoveMenu(m: MenuBase) :=
    sub_menus.RemoveAll(t->t[0]=m);
    
  end;
  
  DummyMenu = class(Menu<byte>)
    
    public procedure Seal; override := exit;
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); override := exit;
    
  end;
  
  ///Container for data of CircleMenu sub-menu
  CircleMenuData = record
    
    public Miniature: Painter;
    public BackColor: System.ValueTuple<real,real,real,real>;
    
    private const ScaleCount = 10;
    private const MaxScale = 1.2;
    private sc_done := -1;
    private scaled_arch := new System.Tuple<real, Painter>[ScaleCount];
    
    private prev_seal_thr: System.Threading.Thread;
    
    
    
    private procedure Seal(R,iR: real; n, MCap: integer);
    
    private procedure AsyncSeal(R,iR: real; n, MCap: integer);
    begin
      if prev_seal_thr<>nil then prev_seal_thr.Abort;
      sc_done := 0;
      
      prev_seal_thr := new System.Threading.Thread(()->self.Seal(R,iR, n, MCap));
      prev_seal_thr.Start;
    end;
    
    public constructor(Miniature: Painter; BackColor: System.ValueTuple<real,real,real,real>);
    begin
      self.Miniature := Miniature;
      self.BackColor := BackColor;
    end;
    
  end;
  
  ///Menu in which all sub-menu's placed in circle
  CircleMenu = class(Menu<CircleMenuData>)
    
    public const MinMenus=5;
    
    protected R,iR: real;
    
    protected bg: Painter;
    protected MCap: integer;
    
    protected const BgScaleCount=40;
    protected bg_sc_done := -1;
    protected scaled_bg := new System.Tuple<real, Painter>[BgScaleCount];
    
    private prev_seal_thr: System.Threading.Thread;
    
    
    
    private constructor := raise new System.NotSupportedException;
    
    private constructor(R, iR: real);
    begin
      self.R := R;
      self.iR := iR;
    end;
    
    
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; cb,cg,cr,ca: real) :=
    AddMenu(m, Miniature, System.ValueTuple.Create(cb,cg,cr,ca));
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; cb,cg,cr,ca: byte) :=
    AddMenu(m, Miniature, new System.ValueTuple<real,real,real,real>(cb/255,cg/255,cr/255,ca/255));
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; BackColor: integer);
    begin
      var pc: ^System.ValueTuple<byte,byte,byte,byte> := pointer(@BackColor);
      AddMenu(m, Miniature, pc^);
    end;
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; BackColor: System.ValueTuple<byte,byte,byte,byte>) :=
    AddMenu(m, Miniature, BackColor.Item1,BackColor.Item2,BackColor.Item3, BackColor.Item4);
    
    public procedure AddMenu(m: MenuBase; Miniature: Image; BackColor: System.ValueTuple<real,real,real,real>) :=
    AddMenu(m, new CircleMenuData(new Painter(Miniature), BackColor));
    
    
    
    //ToDo #1880, #1881
    private function lambda1(t: (MenuBase, CircleMenuData)) := t[1].BackColor;
    private svd_shift: real;
    private svd_clrs: List<System.ValueTuple<real,real,real,real>>;
    private svd_def_cl: System.ValueTuple<real,real,real,real>;
    
    protected function GetScaledBg(sc: real; clrs: List<System.ValueTuple<real,real,real,real>>; def_cl: System.ValueTuple<real,real,real,real>): (real, Painter);
    begin
      var scR := R*sc;
      var sciR := iR*sc;
      
      var w := Ceil(scR * 2);
      var res := new Painter(new Image(w+1,w+1));
      var shift := w/2;
      
      //ToDo #1880, #1881
      svd_shift := shift;
      svd_clrs := clrs;
      svd_def_cl := def_cl;
      
      res.FillRoughDonut(
        shift,shift,
        scR,scR,
        sciR,sciR,
        (x,y)->
        begin
          var ang := Painter.FastArcTan(x-svd_shift,y-svd_shift);
          var i := (Round(ang*MCap) + MCap) mod MCap;
          
          if i<svd_clrs.Count then
            Result := svd_clrs[i] else
            Result := svd_def_cl;
          
        end
      );
      
      var dang := Pi*2/MCap;
      var ang := -dang/2;
      
      //ToDo #1890
      //loop clrs.Count<MCap ? clrs.Count+1 : MCap do
      var temp_loop_var := clrs.Count<MCap ? clrs.Count+1 : MCap;
      while temp_loop_var>0 do
      begin
        var kx := Sin(ang);
        var ky := -Cos(ang);
        
        res.DrawLine(
          shift+kx*sciR,  shift+ky*sciR,
          shift+kx*scR,   shift+ky*scR,
          0,0,0,1
        );
        
        ang += dang;
        temp_loop_var-=1;
      end;
      
      ang := 0;
      var pict_r := Min(
        (R-iR)/2,
        R / (1 + 1/sin(Pi/MCap))
      );
      var pict_dist := R-pict_r;
      var pict_shift := pict_r / sqrt(2);
      var pict_sz := pict_shift*2;
      
      temp_loop_var := 0;
      while temp_loop_var<sub_menus.Count do
      begin
        
        res.DrawPicture(
          shift+Sin(ang)*pict_dist-pict_shift, shift-Cos(ang)*pict_dist-pict_shift,
          pict_sz,pict_sz,
          sub_menus[temp_loop_var][1].Miniature
        );
        
        ang += dang;
        temp_loop_var += 1;
      end;
      
      res.DrawCircle(
        shift,shift,
        scR,scR,
        0,0,0,1
      );
      
      res.DrawCircle(
        shift,shift,
        sciR,sciR,
        0,0,0,1
      );
      
      Result := (shift, res);
      //res.Save($'Temp\bg scale {Round(sc*R)}.bmp');
    end;
    
    //ToDo #1890
    private svd_is_clrs: List<System.ValueTuple<real,real,real,real>>;
    private svd_is_def_cl: System.ValueTuple<real,real,real,real>;
    
    //ToDo #1890
    private procedure InnerSeal :=
    for var i := BgScaleCount-1 downto 0 do
    begin
      if i=0 then
        scaled_bg := scaled_bg;
      
      scaled_bg[i] := GetScaledBg( (i+1)/(BgScaleCount+1), svd_is_clrs, svd_is_def_cl);
      bg_sc_done := BgScaleCount-i;
    end;
    
    ///Starts anync caching of drawable parts of menu
    ///You need to call this before menu would be drawn
    public procedure Seal; override;
    begin
      if prev_seal_thr<>nil then prev_seal_thr.Abort;
      
      MCap := Max(MinMenus, sub_menus.Count);
      //if MCap.IsEven then MCap += 1;
      
      var clrs := sub_menus.ConvertAll(lambda1);
      var def_cl := System.ValueTuple.Create(0.85,0.85,0.85, 0.0);
      
      bg := GetScaledBg(1, clrs, def_cl)[1];
      
      svd_is_clrs := clrs;
      svd_is_def_cl := def_cl;
      
      for var i := 0 to sub_menus.Count-1 do
        sub_menus[i][1].AsyncSeal(R,iR, i, MCap);
      
      bg_sc_done := 0;
      
      prev_seal_thr := new System.Threading.Thread(InnerSeal);
      prev_seal_thr.Start;
    end;
    
    public procedure DrawOn(dx,dy: real; pnt: Painter); override;
    begin
      
      pnt.DrawPicture(dx-R,dy-R, bg);
      
    end;
    
  end;

static procedure MenuBase.GTickCurrent;
begin
  var ToDo := 0;
end;

static procedure MenuBase.DrawCurrent(pnt: Painter);
begin
  var ToDo := 0;
end;

procedure CircleMenuData.Seal(R,iR: real; n, MCap: integer);
begin
  for var i := 0 to ScaleCount-1 do
  begin
    var sc := MaxScale - (MaxScale-1) * (i+1)/ScaleCount;
    
    var w := Ceil(R * sc * 2);
    var res := new Painter(new Image(w+1,w+1));
    var shift := w/2;
    
    var ToDo := 0;
    
    self.scaled_arch[i] := (shift, res);
    sc_done := i+1;
  end;
end;

end.