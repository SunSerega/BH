begin
  try
    foreach var p in System.Diagnostics.Process.GetProcessesByName('BH') do
    try
      p.Kill;
      writeln('killed BH');
    except
      on e: Exception do
        writeln('error killing BH');
    end;
  except
    on e: Exception do
      writeln($'general error');
  end;
  writeln('done');
  readln;
end.