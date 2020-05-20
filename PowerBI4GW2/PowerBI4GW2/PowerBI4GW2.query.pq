let
    Source = PowerBI4GW2.Contents(),
    history = Source{[Name="Silver_Items"]}[Data]
in
    history