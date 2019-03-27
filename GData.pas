unit GData;
{$reference System.Drawing.dll}

type
  
  ///BH image type, that contains of Width, Height and array of color bytes, stored in BGRA format
  Image = sealed class
    
    {$region field's}
    
    public w,h: integer;
    public data: array of byte;//ARGB
    
    {$endregion field's}
    
    {$region Creation}
    
    private constructor := raise new System.NotSupportedException;
    
    ///Initializes new Image with all pixels having empty color ( ARGB : {0,0,0,0} )
    public constructor(w,h: integer);
    begin
      self.w := w;
      self.h := h;
      self.data := new byte[w*h*4];
    end;
    
    ///Get's or set's value of color component #cc, in pixel (x;y)
    public property Pixel[x,y, cc: integer]: byte read data[ (y*w + x)*4 + cc ] write data[ (y*w + x)*4 + cc ] := value; default;
    
    ///Serializes this Image to BinaryWriter
    public procedure Save(bw: System.IO.BinaryWriter);
    begin
      bw.Write(self.w);
      bw.Write(self.h);
      bw.Write(self.data);
    end;
    
    ///Serializes this Image to Stream
    public procedure Save(str: System.IO.Stream) :=
    Save(new System.IO.BinaryWriter(str));
    
    {$endregion Creation}
    
    {$region Loading}
    
    ///Deserializes Image from BinaryReader
    public constructor(br: System.IO.BinaryReader);
    begin
      self.w := br.ReadInt32;
      self.h := br.ReadInt32;
      var sz := w*h*4;
      self.data := br.ReadBytes(sz);
      if self.data.Length<>sz then raise new System.IO.EndOfStreamException('Error reading image body from stream');
    end;
    
    ///Deserializes Image from Stream
    public constructor(str: System.IO.Stream) :=
    Create(new System.IO.BinaryReader(str));
    
    {$endregion Loading}
    
    {$region Drawing}
    
    ///Copyes pixels from specified Image to this one, shifting them by (x;y) vector
    ///Pixels that doesn't fit in this Image bounds wouldn't be copyed
    public procedure DrawOn(x,y: integer; im: Image);
    begin
      var buff_stride := im.w * 4;
      var curr_stride := self.w * 4;
      var copy_stride := Min(curr_stride, (im.w-x) * 4);
      
      var curr_pos := 0;
      var curr_buff_pos := x*4 + y*buff_stride;
      
      loop Min(self.h, im.h-y) do
      begin
        System.Buffer.BlockCopy(self.data, curr_pos, im.data, curr_buff_pos, copy_stride);
        
        curr_pos += curr_stride;
        curr_buff_pos += buff_stride;
      end;
      
    end;
    
    {$endregion Drawing}
    
  end;
  
  //ToDo прозрачность картинок не работает
  //ToDo у всего должны быть варианты: [Draw/Fill]Name[/Rough]. Для Fill ещё перегрузка с лямбдой
  //ToDo для залития кругов не надо высчитывать константы внутри. это МНОГО ДОРОГИХ лишних вычислений
  //ToDo FillDonut сломано, но предыдущее ToDo его всё равно исправило бы
  ///BH alternative for System.Drawing.Graphics
  ///You can derive from this class to extend functionality
  Painter = class(System.IDisposable)
    
    //ToDo Debug
    public static function GetKeyState(nVirtKey: byte): byte;
    external 'User32.dll' name 'GetKeyState';
    
    {$region field's}
    
    protected hnd: System.Runtime.InteropServices.GCHandle;
    
    protected bmp: System.Drawing.Bitmap;
    protected bmp_data: System.Drawing.Imaging.BitmapData;
    
    protected buff: System.IntPtr;
    protected buff_w, buff_h, buff_stride: integer;
    
    {$endregion field's}
    
    {$region constructor's}
    
    private constructor := raise new System.NotSupportedException;
    
    ///Constructs new Painter to draw on specified Image
    ///Make sure to .Dispose this Painter after use, to unpinn Image buffer
    public constructor(im: Image);
    begin
      self.hnd := System.Runtime.InteropServices.GCHandle.Alloc(im.data, System.Runtime.InteropServices.GCHandleType.Pinned);
      self.buff := hnd.AddrOfPinnedObject;
      self.buff_w := im.w;
      self.buff_h := im.h;
      self.buff_stride := im.w*4;
    end;
    
    ///Constructs new Painter to draw on specified Bitmap
    ///Make sure to .Dispose this Painter after use, for UnLockBits to be called on Bitmap
    public constructor(bmp: System.Drawing.Bitmap);
    begin
      self.bmp := bmp;
      self.bmp_data := bmp.LockBits(
        new System.Drawing.Rectangle(0,0, bmp.Width,bmp.Height),
        System.Drawing.Imaging.ImageLockMode.ReadWrite,
        System.Drawing.Imaging.PixelFormat.Format32bppArgb
      );
      self.buff := bmp_data.Scan0;
      self.buff_w := bmp_data.Width;
      self.buff_h := bmp_data.Height;
      self.buff_stride := bmp_data.Stride;
    end;
    
    ///Constructs new Painter from unmannaged buffer data
    ///Doesn't need to .Dispose after use, but requares you to do all memory locks yourself
    public constructor(buff: System.IntPtr; buff_w, buff_h, buff_stride: integer);
    begin
      self.buff := buff;
      self.buff_w := buff_w;
      self.buff_h := buff_h;
      self.buff_stride := buff_stride;
    end;
    
    {$endregion constructor's}
    
    {$region Misc}
    
    protected function GetAdr(x,y: integer) :=
    buff + (y*buff_stride + x*4);
    
    public procedure Save(fname: string);
    begin
      if self.bmp <> nil then
      begin
        bmp.Save(fname);
        exit;
      end;
      
      var bmp := new System.Drawing.Bitmap(buff_w,buff_h);
      var tpnt := new Painter(bmp);
      tpnt.DrawPicture(0,0,self);
      tpnt.Dispose;
      
      bmp.Save(fname);
    end;
    
    private const FATP = 2520;
    
    private static function InitFAT_buff: array of real;
    begin
      Result := new real[FATP];
      
      for var i := 0 to FATP-1 do
      begin
        
        // i = FATP / (dy/dx+1)
        // i = FATP / ( -Cos(ang)/Sin(ang) +1)
        // i = FATP / (-ctg(ang)+1)
        // -ctg(ang) + 1 = FATP / i
        // 1/tg(ang) = 1-FATP / i
        // tg(ang) = 1 / (1-FATP / i)
        // ang = ArcTan( 1 / (1-FATP / i) )
        
        Result[i] := -ArcTan( 1 / (1-FATP / i) )/2/Pi + 1/FATP/2/4;
      end;
      
    end;
    
    private static FAT_buff := InitFAT_buff;
    
    ///Result is clockwise angle from (0;-1), in range [0,1)
    ///Error is < 1/2520
    public static function FastArcTan(dx,dy: real): real;
    begin
      
      if dx=0 then
      begin
        
        if dy<0 then Result := 0.00 else
        if dy>0 then Result := 0.50 else
          Result := real.NaN;
        
        exit;
      end;
      
      if dy=0 then
      begin
        
        if dx>0 then Result := 0.25 else
        if dx<0 then Result := 0.75 else
          Result := real.NaN;
        
        exit;
      end;
      
      var k: real;
      
      if dx<0 then
      begin
        
        if dy<0 then
        begin
          k := abs(dy/dx);
          Result := FAT_buff[FATP - Ceil( FATP / (k+1) ) ] + 0.75;
        end else
        begin
          k := abs(dy/dx);
          Result := FAT_buff[ Ceil( FATP / (k+1) )-1 ] + 0.50;
        end;
        
      end else
      begin
        
        if dy<0 then
        begin
          k := abs(dy/dx);
          Result := FAT_buff[ Ceil( FATP / (k+1) )-1 ];
        end else
        begin
          k := abs(dy/dx);
          Result := FAT_buff[FATP - Ceil( FATP / (k+1) ) ] + 0.25;
        end;
        
      end;
      
    end;
    
    {$endregion Misc}
    
    {$region Pixel's}
    
    {$region GetPixel}
    
    protected function GetPixel(adr: pointer): System.ValueTuple<byte,byte,byte,byte>;
    begin
      System.Buffer.MemoryCopy(
        adr, @Result,
        4,4
      );
    end;
    
    ///Return's color of pixel at (x; y) in BGRA format
    ///Causes undefined behavior, if point (x;y) is outside of bounds
    public function GetPixel(x,y: integer) :=
    GetPixel(pointer(GetAdr(x,y)));
    
    ///Return's color of pixel at (x; y) in BGRA format
    ///Return's empty color, if point (x;y) is outside of bounds
    public function GetPixelOrEmpty(x,y: integer): System.ValueTuple<byte,byte,byte,byte>;
    begin
      if x<0 then exit;
      if y<0 then exit;
      if x>buff_w-1 then exit;
      if y>buff_w-1 then exit;
      Result := GetPixel(x,y);
    end;
    
    protected function GetFloatPixelOrEmpty(x,y: integer): System.ValueTuple<real,real,real,real>;
    begin
      if x<0 then exit;
      if y<0 then exit;
      if x>buff_w-1 then exit;
      if y>buff_w-1 then exit;
      var px := GetPixel(x,y);
      Result.Item1 := px.Item1/255;
      Result.Item2 := px.Item2/255;
      Result.Item3 := px.Item3/255;
      Result.Item4 := px.Item4/255;
    end;
    
    ///for draw pict with float x,y and no w,h
    protected function GetAveragePixelOf4(x,y: integer; a1,a2,a3,a4: real): System.ValueTuple<real,real,real,real>;
    begin
      
      var px1 := GetFloatPixelOrEmpty(x,   y  );
      var px2 := GetFloatPixelOrEmpty(x-1, y  );
      var px3 := GetFloatPixelOrEmpty(x-1, y-1);
      var px4 := GetFloatPixelOrEmpty(x,   y-1);
      
      //Result.Item4 := ( px1.Item4*a1 + px2.Item4*a2 + px3.Item4*a3 + px4.Item4*a4 ); //без деления на vs, ибо a1+a2+a3+a4=1
      //if Result.Item4<0.001 then exit;
      
      a1 *= px1.Item4;
      a2 *= px2.Item4;
      a3 *= px3.Item4;
      a4 *= px4.Item4;
      var vs := a1+a2+a3+a4;
      if vs<0.001 then exit;
      
      Result.Item4 := vs;//это то же самое что выше
      
      Result.Item1 := ( px1.Item1*a1 + px2.Item1*a2 + px3.Item1*a3 + px4.Item1*a4 ) / vs;
      Result.Item2 := ( px1.Item2*a1 + px2.Item2*a2 + px3.Item2*a3 + px4.Item2*a4 ) / vs;
      Result.Item3 := ( px1.Item3*a1 + px2.Item3*a2 + px3.Item3*a3 + px4.Item3*a4 ) / vs;
      
      //writeln(Result);
    end;
    
    protected procedure AddPxToAvr(var res: System.ValueTuple<real,real,real,real>; px: System.ValueTuple<real,real,real,real>; k: real);
    begin
      var ck := px.Item4 * k;
      
      res.Item1 += px.Item1 * ck;
      res.Item2 += px.Item2 * ck;
      res.Item3 += px.Item3 * ck;
      res.Item4 += ck;
    end;
    
    ///Counts average pixel in rectangular area, limited by points (x1;y1) and (x2;y2)
    public function GetAveragePixel(x1,y1, x2,y2: real): System.ValueTuple<real,real,real,real>;
    begin
      
      var wk := x2-x1;
      var hk := y2-y1;
      
      Result := GetAveragePixel(x1,y1, x2,y2, wk,hk, wk*hk);
    end;
    
    ///Counts average pixel in rectangular area, limited by points (x1;y1) and (x2;y2)
    ///Next values must be:
    ///wk = x2-x1
    ///hk = y2-y1
    ///ks = wk*hk
    ///This overload is for mass use of GetAveragePixel, where wk, hk and ks already known
    public function GetAveragePixel(x1,y1, x2,y2, wk, hk, ks: real): System.ValueTuple<real,real,real,real>;
    begin
      
      var ix1 := Floor(x1);
      var iy1 := Floor(y1);
      
      var ix2 := Ceil(x2);
      var iy2 := Ceil(y2);
      
      var w := ix2-ix1; if w<1 then exit;
      var h := iy2-iy1; if h<1 then exit;
      
      var pxls := MatrGen(w,h, (x,y)->self.GetFloatPixelOrEmpty(ix1+x, iy1+y) );//ToDo лучше читать походу, а проверка есть и в конце. кроме всего прочего, если запрашивается большая область за граицами - можно будет и не пробовать читать, так меньше проверок
      if pxls.ElementsByRow.All(px->px.Item4<0.001) then exit;
      
      var k1 :=   x2 - ix2 + 1;//Right, next clockwise
      var k2 :=   y2 - iy2 + 1;
      var k3 :=  ix1 -  x1 + 1;
      var k4 :=  iy1 -  y1 + 1;
      
      //usefull info:
      //if w=1 then k1+k3-1 = wk
      //if h=1 then k2+k4-1 = hk
      
      if w=1 then
      begin
        
        if h=1 then
        begin
          //AddPxToAvr(Result, pxls[0,0], ks );
          
          Result := pxls[0,0];
          //Result.Item4 *= ks;//if only one px - it painted the whole result px, no reason to change Alpha
          exit;
          
        end else
        begin
          
          AddPxToAvr(Result, pxls[0, h-1], wk*k2);
          AddPxToAvr(Result, pxls[0, 0  ], wk*k4);
          
          for var y := 1 to h-2 do
            AddPxToAvr(Result, pxls[0, y], wk);
          
        end;
        
      end else
      begin
        
        if h=1 then
        begin
          
          AddPxToAvr(Result, pxls[w-1, 0], hk*k1);
          AddPxToAvr(Result, pxls[0  , 0], hk*k3);
          
          for var x := 1 to w-2 do
            AddPxToAvr(Result, pxls[x, 0], hk);
          
        end else
        begin
          
          for var y := 1 to h-2 do
            for var x := 1 to w-2 do
              AddPxToAvr(Result, pxls[x,y], 1);
          
          for var y := 1 to h-2 do
          begin
            AddPxToAvr(Result, pxls[w-1, y], k1);
            AddPxToAvr(Result, pxls[0  , y], k3);
          end;
          
          for var x := 1 to w-2 do
          begin
            AddPxToAvr(Result, pxls[x, h-1], k2);
            AddPxToAvr(Result, pxls[x, 0  ], k4);
          end;
          
          AddPxToAvr(Result, pxls[0  , 0  ], k3*k4);
          AddPxToAvr(Result, pxls[w-1, 0  ], k1*k4);
          AddPxToAvr(Result, pxls[w-1, h-1], k1*k2);
          AddPxToAvr(Result, pxls[0  , h-1], k3*k2);
          
        end;
        
      end;
      
      if Result.Item4<0.001 then
      begin
        Result := default(System.ValueTuple<real,real,real,real>);
        exit;
      end;
      
      Result.Item1 /= Result.Item4;
      Result.Item2 /= Result.Item4;
      Result.Item3 /= Result.Item4;
      Result.Item4 /= ks;
    end;
    
    {$endregion GetPixel}
    
    {$region SetPixel}
    
    ///Set's color of pixel at (x; y) to P-BGRA format color
    public procedure SetPixel(x,y: integer; cp: pointer);
    begin
      System.Buffer.MemoryCopy(
        cp, pointer(GetAdr(x,y)),
        4,4
      );
    end;
    
    ///Set's color of pixel at (x; y) in BGRA format
    public procedure SetPixel(x,y: integer; c: System.ValueTuple<byte,byte,byte,byte>) := SetPixel(x,y, @c);
    
    ///Set's color of pixel at (x; y) to BGRA : {cb, cg, cr, ca}
    public procedure SetPixel(x,y: integer; cb,cg,cr,ca: byte) :=
    SetPixel(x,y, System.ValueTuple.Create(cb,cg,cr,ca));
    
    ///Set's color of pixel at (x; y) in BGRA format stored in 32-bit integer
    ///Bytes of integers are stored in reverse order
    ///So hex value of FFFF00FF would be purple, as if it was in ARGB
    public procedure SetPixel(x,y: integer; c: integer) := SetPixel(x,y, @c);
    
    {$endregion SetPixel}
    
    {$region AlterPixel}
    
    protected procedure AlterPixel(adr: pointer; cb,cg,cr,ca: real);
    begin
      var px: System.ValueTuple<byte,byte,byte,byte>;
      
      if ca>0.999 then
      begin
        px.Item1 := System.Convert.ToByte(cb*255);
        px.Item2 := System.Convert.ToByte(cg*255);
        px.Item3 := System.Convert.ToByte(cr*255);
        px.Item4 := 255;
        
        System.Buffer.MemoryCopy(
          @px, adr,
          4,4
        );
        
        exit;
      end;
      
      System.Buffer.MemoryCopy(
        adr, @px,
        4,4
      );
      
      var nca := ca + 1 - px.Item4/255;
      if nca>1 then nca := 1;
      px.Item4 := Min(255, px.Item4 + System.Convert.ToInt32( ca*255 ));
      
      px.Item1 += System.Convert.ToInt32( (cb*255-px.Item1) * nca );
      px.Item2 += System.Convert.ToInt32( (cg*255-px.Item2) * nca );
      px.Item3 += System.Convert.ToInt32( (cr*255-px.Item3) * nca );
      
      System.Buffer.MemoryCopy(
        @px, adr,
        4,4
      );
      
    end;
    
    ///Changes color of pixel at (x,y), applying BGRA color stored in {cb,cg,cr,ca}
    ///All color components must be in [0;1) range
    ///Formula used here: px.t += (ct-px.t) * (ca + (1-px.a) );
    public procedure AlterPixel(x,y: integer; cb,cg,cr,ca: real) :=
    AlterPixel(pointer(GetAdr(x,y)), cb,cg,cr,ca);
    
    ///Changes color of pixel at (x,y), applying BGRA color stored in c
    ///All color components must be in [0;1) range
    ///Formula used here: px.t += (ct-px.t) * (ca + (1-px.a) );
    public procedure AlterPixel(x,y: integer; c: System.ValueTuple<real,real,real,real>) :=
    AlterPixel(x,y, c.Item1,c.Item2,c.Item3, c.Item4);
    
    {$endregion AlterPixel}
    
    {$endregion Pixel's}
    
    {$region Fill}
    
    ///Set's color of all pixel's to P-BGRA format color
    public procedure Fill(cp: pointer);
    begin
      var curr_row_pos := buff;
      
      loop buff_h do
      begin
        var curr_pos := curr_row_pos;
        
        loop buff_w do
        begin
          
          System.Buffer.MemoryCopy(cp,pointer(curr_pos), 4,4);
          
          curr_pos := curr_pos + 4;
        end;
        
        curr_row_pos := curr_row_pos + buff_stride;
      end;
      
    end;
    
    ///Set's color of all pixel's in BGRA format
    public procedure Fill(c: System.ValueTuple<byte,byte,byte,byte>) := Fill(@c);
    
    ///Set's color of all pixel's in BGRA : {cb, cg, cr, ca}
    public procedure Fill(cb,cg,cr,ca: byte) :=
    Fill(System.ValueTuple.Create(cb,cg,cr,ca));
    
    ///Set's color of all pixel's in BGRA format stored in 32-bit integer
    public procedure Fill(c: integer) := Fill(@c);
    
    {$endregion Fill}
    
    {$region Line's}
    
    ///Draws line from (x1;y1) to (x2;y2) with color BGRA : {cb, cg, cr, ca}
    public procedure DrawLine(x1,y1, x2,y2: real; cb,cg,cr,ca: real);
    begin
      
      var XYSwaped := abs(y2-y1) > abs(x2-x1);
      if XYSwaped then
      begin
        Swap(x1,y1);
        Swap(x2,y2);
      end;
      
      var w := buff_w;
      var h := buff_h;
      
      if x1>x2 then
      begin
        Swap(x1,x2);
        Swap(y1,y2);
        Swap(w,h);
      end;
      
      var a := (y2-y1) / (x2-x1);
      var b := y1 - x1*a;
      
      for var x := Max(0, x1.Round) to Min(x2.Round, w-1) do
      begin
        var y := x*a + b;
        if y <= -1 then continue;
        if y >=  h then continue;
        
        var iy := System.Convert.ToInt32(System.Math.Floor(y));
        var pa := y-iy;
        
        if XYSwaped then
        begin
          if iy<>-1 then  AlterPixel(iy,  x, cr,cg,cb, ca*(1-pa));
          if iy<>h-1 then AlterPixel(iy+1,x, cr,cg,cb, ca*pa);
        end else
        begin
          if iy<>-1 then  AlterPixel(x,  iy, cr,cg,cb, ca*(1-pa));
          if iy<>h-1 then AlterPixel(x,iy+1, cr,cg,cb, ca*pa);
        end;
        
      end;
      
    end;
    
    {$endregion Line's}
    
    {$region Round Objects}
    
    {$region Circle}
    
    public procedure DrawCircle(x,y, wr,hr: real; cb,cg,cr,ca: real);
    begin
      
      for var iy := Max( 0, Floor(y-hr)-10 ) to Min( Ceil(y+hr)+10, self.buff_h-1 ) do
      begin
        var x_sq := ( 1 - sqr( (iy-y)/hr ) );
        if x_sq<0 then continue;
        var dx := x_sq.Sqrt*wr;
        
        var ix := Round(x-dx);
        if ix<0            then ix := 0 else
        if ix>=self.buff_w then ix := self.buff_w-1;
        
        var rx,ry, k: real;
        ry := iy-y;
        
        var curr_x := ix;
        while curr_x>=0 do
        begin
          
          rx := curr_x-x;
          
          k := 1-
            Sqrt( Sqr(rx) + Sqr(ry) ) *
            abs(1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) );
          
          if k<0 then break;
          
          self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
          
          curr_x -= 1;
        end;
        if curr_x=ix then continue;
        
        curr_x := ix+1;
        while curr_x<self.buff_w do
        begin
          
          rx := curr_x-x;
          
          k := 1-
            Sqrt( Sqr(rx) + Sqr(ry) ) *
            abs(1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) );
          
          if k<0 then break;
          
          self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
          
          curr_x += 1;
        end;
        if curr_x>x then continue;
        
        ix := Round(x+dx);
        if ix<0            then ix := 0 else
        if ix>=self.buff_w then ix := self.buff_w-1;
        
        curr_x := ix;
        while curr_x>=0 do
        begin
          
          rx := curr_x-x;
          
          k := 1-
            Sqrt( Sqr(rx) + Sqr(ry) ) *
            abs(1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) );
          
          if k<0 then break;
          
          self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
          
          curr_x -= 1;
        end;
        if curr_x=ix then continue;
        
        curr_x := ix+1;
        while curr_x<self.buff_w do
        begin
          
          rx := curr_x-x;
          
          k := 1-
            Sqrt( Sqr(rx) + Sqr(ry) ) *
            abs(1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) );
          
          if k<0 then break;
          
          self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
          
          curr_x += 1;
        end;
        
      end;
      
    end;
    
    public procedure FillCircle(x,y, wr,hr: real; cb,cg,cr,ca: real);
    begin
      
      for var iy := Max( 0, Floor(y-hr) ) to Min( Ceil(y+hr), self.buff_h-1 ) do
      begin
        var x_sq := ( 1 - sqr( (iy-y)/hr ) );
        if x_sq<0 then continue;
        var dx := x_sq.Sqrt*wr;
        
        var ix := Round(x-dx);
        if ix<0            then ix := 0 else
        if ix>=self.buff_w then ix := self.buff_w-1;
        
        var rx,ry, k: real;
        ry := iy-y;
        
        var curr_x := ix;
        while curr_x>=0 do
        begin
          
          rx := curr_x-x;
          
          k := 1-
            Sqrt( Sqr(rx) + Sqr(ry) ) *
            (1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) );
          
          if k<0 then break;
          
          self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
          
          curr_x -= 1;
        end;
        if curr_x=ix then continue;
        
        curr_x := ix+1;
        
        while curr_x<self.buff_w do
        begin
          
          rx := curr_x-x;
          
          var l_sq := Sqr(rx) + Sqr(ry);
          k :=
            l_sq<0.5?(
              1
            ):(
              1 -
              l_sq.Sqrt *
              (1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) )
            );
          
          if k<0 then break;
          if k>1 then k := 1;
          
          self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
          
          curr_x += 1;
        end;
        
      end;
      
    end;
    
    {$endregion Circle}
    
    {$region Donut}
    
    public procedure FillDonut_Broken(x,y, wr,hr, iwr,ihr: real; cb,cg,cr,ca: real);
    begin
      
      for var iy := Max( 0, Floor(y-hr) ) to Min( Ceil(y+hr), self.buff_h-1 ) do
      begin
        var x_sq := ( 1 - sqr( (iy-y)/hr ) );
        if x_sq<0 then continue;
        var dx := x_sq.Sqrt*wr;
        
        var ix := Round(x-dx);
        if ix<0            then ix := 0 else
        if ix>=self.buff_w then ix := self.buff_w-1;
        
        var rx,ry, k: real;
        ry := iy-y;
        
        var curr_x := ix;
        while curr_x>=0 do
        begin
          
          rx := curr_x-x;
          
          k := 1-
            Sqrt( Sqr(rx) + Sqr(ry) ) *
            (1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) );
          
          if k<0 then break;
          
          self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
          
          curr_x -= 1;
        end;
        if curr_x=ix then continue;
        
        curr_x := ix+1;
        
        x_sq := ( 1 - sqr( (iy-y)/ihr ) );
        if x_sq>0 then
        begin
          
          while curr_x<self.buff_w do
          begin
            
            rx := curr_x-x;
            
            var l_sq := Sqr(rx) + Sqr(ry);
            k :=
              l_sq<0.5?(
                1
              ):(
                Min(
                  1 -
                  l_sq.Sqrt *
                  (1 / Sqrt( Sqr(rx/iwr) + Sqr(ry/ihr) ) - 1)
                ,
                  1 -
                  l_sq.Sqrt *
                  (1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) )
                )
              );
            
            if k<0 then break;
            if k>1 then k := 1;
            
            self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
            
            curr_x += 1;
          end;
          if curr_x=self.buff_w then continue;
          
          dx :=x_sq.Sqrt*iwr;
          
          ix := Round(x+dx);
          if ix<0            then ix := 0 else
          if ix>=self.buff_w then ix := self.buff_w-1;
          
          curr_x := ix;
          while curr_x>=0 do
          begin
            
            rx := curr_x-x;
            
            var l_sq := Sqr(rx) + Sqr(ry);
            k :=
              l_sq<0.5?(
                1
              ):(
                1 -
                l_sq.Sqrt *
                (1 / Sqrt( Sqr(rx/iwr) + Sqr(ry/ihr) ) - 1)
              );
            
            if k<0 then break;
            if k>1 then k := 1;
            
            self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
            
            curr_x -= 1;
          end;
          
          curr_x := ix+1;
        end;
        
        while curr_x<self.buff_w do
        begin
          
          rx := curr_x-x;
          
          var l_sq := Sqr(rx) + Sqr(ry);
          k :=
            l_sq<0.5?(
              1
            ):(
              1 -
              l_sq.Sqrt *
              (1 - 1 / Sqrt( Sqr(rx/wr) + Sqr(ry/hr) ) )
            );
          
          if k<0 then break;
          if k>1 then k := 1;
          
          self.AlterPixel( curr_x, iy, cb,cg,cr, ca*k );
          
          curr_x += 1;
        end;
        
      end;
      
    end;
    
    public procedure FillRoughDonut(x,y, wr,hr, iwr,ihr: real; get_px: (integer,integer)->System.ValueTuple<real,real,real,real>);
    begin
      //var sw := new System.Diagnostics.Stopwatch;
      
      for var iy := Max( 0, Floor(y-hr-1) ) to Min( Ceil(y+hr+1), self.buff_h-1 ) do
      begin
        var x_sq := ( 1 - sqr( (iy-y)/hr ) );
        if x_sq<0 then continue;
        var dx := x_sq.Sqrt * wr;
        
        var ix1 := Ceil(x-dx);
        if ix1<0            then ix1 := 0 else
        if ix1>=self.buff_w then ix1 := self.buff_w-1;
        
        var ix2 := Floor(x+dx);
        if ix2<0            then ix2 := 0 else
        if ix2>=self.buff_w then ix2 := self.buff_w-1;
        
        if abs(y-iy) > ihr then
        begin
          
//          for var ix := ix1 to ix2 do self.AlterPixel(ix,iy, get_px(ix,iy) );
          for var ix := ix1 to ix2 do
          begin
            //sw.Start;
            var px := get_px(ix,iy);
            //sw.Stop;
            if px.Item4<0.001 then continue;
            self.AlterPixel(ix,iy, px);
          end;
          
          
        end else
        begin
          
          dx := Sqrt( 1 - sqr( (iy-y)/ihr ) ) * iwr;
          
          var iix1 := Ceil(x-dx)-1;
          if iix1<0            then iix1 := 0 else
          if iix1>=self.buff_w then iix1 := self.buff_w-1;
          
          var iix2 := Floor(x+dx)+1;
          if iix2<0            then iix2 := 0 else
          if iix2>=self.buff_w then iix2 := self.buff_w-1;
          
//          for var ix := ix1 to iix1 do self.AlterPixel(ix,iy, get_px(ix,iy) );
//          for var ix := iix2 to ix2 do self.AlterPixel(ix,iy, get_px(ix,iy) );
          
          for var ix := ix1 to iix1 do
          begin
            //sw.Start;
            var px := get_px(ix,iy);
            //sw.Stop;
            if px.Item4<0.001 then continue;
            self.AlterPixel(ix,iy, px);
          end;
          
          for var ix := iix2 to ix2 do
          begin
            //sw.Start;
            var px := get_px(ix,iy);
            //sw.Stop;
            if px.Item4<0.001 then continue;
            self.AlterPixel(ix,iy, px);
          end;
          
        end;
        
      end;
      
      //writeln('FillRoughDonut.get_px ', sw.Elapsed);
    end;
    
    {$endregion Donut}
    
    {$region Arch}
    
    
    
    {$endregion Arch}
    
    {$endregion Round Objects}
    
    {$region Picture}
    
    ///Copies picture opened in pnt to the current picture at (x;y)
    ///This is faster then DrawPicture, but transparency is ignored
    public procedure CopyPicture(x,y: integer; pnt: Painter);
    begin
      var copy_stride := Min(pnt.buff_stride, self.buff_stride-x*4);
      
      var curr_pnt_pos := pnt.buff;
      var curr_self_pos := self.buff + (y*self.buff_stride + x*4);
      
      loop Min(pnt.buff_h, self.buff_h-y) do
      begin
        System.Buffer.MemoryCopy(pointer(curr_pnt_pos), pointer(curr_self_pos), copy_stride, copy_stride);
        
        curr_pnt_pos := curr_pnt_pos + pnt.buff_stride;
        curr_self_pos := curr_self_pos + self.buff_stride;
      end;
      
    end;
    
    ///Copies Rectangle(ix, iy, cw,ch) area from picture opened in pnt to the current picture at (x;y)
    ///This is faster then DrawPicture, but transparency is ignored
    public procedure CopyPicture(x,y, ix,iy, cw,ch: integer; pnt: Painter);
    begin
      var copy_stride := Min(cw*4, self.buff_stride-x*4);
      
      var curr_pnt_pos := pnt.buff + (iy*pnt.buff_stride + ix*4);
      var curr_self_pos := self.buff + (y*self.buff_stride + x*4);
      
      loop Min(ch, self.buff_h-y) do
      begin
        System.Buffer.MemoryCopy(pointer(curr_pnt_pos), pointer(curr_self_pos), copy_stride, copy_stride);
        
        curr_pnt_pos := curr_pnt_pos + pnt.buff_stride;
        curr_self_pos := curr_self_pos + self.buff_stride;
      end;
      
    end;
    
    ///Draws picture opened in pnt at (x;y)
    public procedure DrawPicture(x,y: integer; pnt: Painter);
    begin
      var copy_w := Min(pnt.buff_w, self.buff_w-x);
      
      var curr_pnt_row_pos := pnt.buff;
      var curr_self_row_pos := self.buff + (y*self.buff_stride + x*4);
      
      loop Min(pnt.buff_h, self.buff_h-y) do
      begin
        var curr_pnt_pos := curr_pnt_row_pos;
        var curr_self_pos := curr_self_row_pos;
        
        loop copy_w do
        begin
          
          var px := pnt.GetPixel(pointer(curr_pnt_pos));
          AlterPixel(pointer(curr_self_pos), px.Item1/255, px.Item2/255, px.Item3/255, px.Item4/255);
          
          curr_pnt_pos := curr_pnt_pos + 4;
          curr_self_pos := curr_self_pos + 4;
        end;
        
        curr_pnt_row_pos := curr_pnt_row_pos + pnt.buff_stride;
        curr_self_row_pos := curr_self_row_pos + self.buff_stride;
      end;
      
    end;
    
    ///Draws Rectangle(ix, iy, cw,ch) area from picture opened in pnt at (x;y)
    public procedure DrawPicture(x,y, ix,iy, cw,ch: integer; pnt: Painter);
    begin
      var copy_w := Min(cw, self.buff_w-x);
      
      var curr_pnt_row_pos := pnt.buff + (iy*pnt.buff_stride + ix*4);
      var curr_self_row_pos := self.buff + (y*self.buff_stride + x*4);
      
      loop Min(ch, self.buff_h-y) do
      begin
        var curr_pnt_pos := curr_pnt_row_pos;
        var curr_self_pos := curr_self_row_pos;
        
        loop copy_w do
        begin
          
          var px := pnt.GetPixel(pointer(curr_pnt_pos));
          AlterPixel(pointer(curr_self_pos), px.Item1/255, px.Item2/255, px.Item3/255, px.Item4/255);
          
          curr_pnt_pos := curr_pnt_pos + 4;
          curr_self_pos := curr_self_pos + 4;
        end;
        
        curr_pnt_row_pos := curr_pnt_row_pos + pnt.buff_stride;
        curr_self_row_pos := curr_self_row_pos + self.buff_stride;
      end;
      
    end;
    
    ///Draws picture opened in pnt at (x;y)
    public procedure DrawPicture(x,y: real; pnt: Painter);
    begin
      var ix := x.Trunc;
      var iy := y.Trunc;
//      var ix := Ceil(x)-1;
//      var iy := Ceil(y)-1;
      
      var rx := 1-(x-ix);
      var ry := 1-(y-iy);
      
      var a1 := rx     * ry;
      var a2 := (1-rx) * ry;
      var a3 := (1-rx) * (1-ry);
      var a4 := rx     * (1-ry);
      
      for var dy := 0 to pnt.buff_h do
        for var dx := 0 to pnt.buff_w do
        begin
          var px := pnt.GetAveragePixelOf4(dx,dy, a1,a2,a3,a4);
          self.AlterPixel(ix+dx, iy+dy, px.Item1, px.Item2,px.Item3,px.Item4);
        end;
      
    end;
    
    ///Draws picture opened in pnt at (x;y), scaling it to size (w;h)
    public procedure DrawPicture(x,y, w,h: real; pnt: Painter);
    begin
      var ix1 := Floor(x);
      var iy1 := Floor(y);
      var ix2 := Ceil(x+w)-1;
      var iy2 := Ceil(y+h)-1;
      
      if ix1<0 then ix1 := 0;
      if iy1<0 then iy1 := 0;
      if ix2>self.buff_w-1 then ix2 := self.buff_w-1;
      if iy2>self.buff_h-1 then iy2 := self.buff_h-1;
      
      var wk := pnt.buff_w/w;
      var hk := pnt.buff_h/h;
      var ks := wk*hk;
      
      for var dy := iy1 to iy2 do
        for var dx := ix1 to ix2 do
        begin
          
          var px := pnt.GetAveragePixel(
            (dx  -x) * wk,
            (dy  -y) * hk,
            (dx+1-x) * wk,
            (dy+1-y) * hk,
            wk,hk,ks
          );
          self.AlterPixel(dx, dy, px.Item1, px.Item2,px.Item3,px.Item4);
          
        end;
      
    end;
    
    {$endregion Picture}
    
    {$region destructor's}
    
    public procedure Dispose;
    begin
      
      if hnd.IsAllocated then hnd.Free;
      
      if bmp<>nil then
      begin
        bmp.UnlockBits(bmp_data);
        bmp := nil;
        bmp_data := nil;
      end;
      
    end;
    
    public procedure Finalize; override :=
    Dispose;
    
    {$endregion destructor's}
    
  end;
  
end.