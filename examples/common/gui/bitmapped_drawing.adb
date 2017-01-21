------------------------------------------------------------------------------
--                                                                          --
--                     Copyright (C) 2015-2016, AdaCore                     --
--                                                                          --
--  Redistribution and use in source and binary forms, with or without      --
--  modification, are permitted provided that the following conditions are  --
--  met:                                                                    --
--     1. Redistributions of source code must retain the above copyright    --
--        notice, this list of conditions and the following disclaimer.     --
--     2. Redistributions in binary form must reproduce the above copyright --
--        notice, this list of conditions and the following disclaimer in   --
--        the documentation and/or other materials provided with the        --
--        distribution.                                                     --
--     3. Neither the name of the copyright holder nor the names of its     --
--        contributors may be used to endorse or promote products derived   --
--        from this software without specific prior written permission.     --
--                                                                          --
--   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS    --
--   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT      --
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR  --
--   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   --
--   HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, --
--   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT       --
--   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,  --
--   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY  --
--   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT    --
--   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  --
--   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.   --
--                                                                          --
------------------------------------------------------------------------------

with HAL; use HAL;

package body Bitmapped_Drawing is

   ---------------
   -- Draw_Char --
   ---------------

   procedure Draw_Char
     (Buffer     : in out Bitmap_Buffer'Class;
      Start      : Point;
      Char       : Character;
      Font       : BMP_Font;
      Foreground : Unsigned_32;
      Background : Unsigned_32)
   is
   begin
      for H in 0 .. Char_Height (Font) - 1 loop
         for W in 0 .. Char_Width (Font) - 1 loop
            if (Data (Font, Char, H) and Mask (Font, W)) /= 0 then
               Buffer.Set_Pixel
                 (Start.X + W, Start.Y + H, Foreground);
            else
               Buffer.Set_Pixel
                 (Start.X + W, Start.Y + H, Background);
            end if;
         end loop;
      end loop;
   end Draw_Char;

   -----------------
   -- Draw_String --
   -----------------

   procedure Draw_String
     (Buffer     : in out Bitmap_Buffer'Class;
      Start      : Point;
      Msg        : String;
      Font       : BMP_Font;
      Foreground : Bitmap_Color;
      Background : Bitmap_Color)
   is
      Count : Natural := 0;
      FG    : constant Unsigned_32 := Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                            Foreground);
      BG    : constant Unsigned_32 := Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                            Background);
   begin
      for C of Msg loop
         exit when Start.X + Count * Char_Width (Font) > Buffer.Width;
         Draw_Char
           (Buffer,
            (Start.X + Count * Char_Width (Font), Start.Y),
            C,
            Font,
            FG,
            BG);
         Count := Count + 1;
      end loop;
   end Draw_String;

   -----------------
   -- Draw_String --
   -----------------

   procedure Draw_String
     (Buffer     : in out Bitmap_Buffer'Class;
      Start      : Point;
      Msg        : String;
      Font       : Hershey_Font;
      Height     : Natural;
      Bold       : Boolean;
      Foreground : Bitmap_Color;
      Fast       : Boolean := True)
   is
      FG    : constant UInt32 := Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                     Foreground);

      procedure Internal_Draw_Line
        (X0, Y0, X1, Y1 : Natural;
         Width          : Positive);

      procedure Internal_Draw_Line
        (X0, Y0, X1, Y1 : Natural;
         Width          : Positive)
      is
      begin
         Draw_Line (Buffer,
                    (X0, Y0),
                    (X1, Y1),
                    FG,
                    Width,
                    Fast => Fast);
      end Internal_Draw_Line;

      procedure Draw_Glyph is new Hershey_Fonts.Draw_Glyph
        (Internal_Draw_Line);

      Current : Point := Start;

   begin
      for C of Msg loop
         exit when Current.X > Buffer.Width;
         Draw_Glyph
           (Fnt    => Font,
            C      => C,
            X      => Current.X,
            Y      => Current.Y,
            Height => Height,
            Bold   => Bold);
      end loop;
   end Draw_String;

   -----------------
   -- Draw_String --
   -----------------

   procedure Draw_String
     (Buffer     : in out Bitmap_Buffer'Class;
      Area       : Rect;
      Msg        : String;
      Font       : Hershey_Font;
      Bold       : Boolean;
      Outline    : Boolean;
      Foreground : Bitmap_Color;
      Fast       : Boolean := True)
   is
      Length  : constant Natural :=
                  Hershey_Fonts.Strlen (Msg, Font, Area.Height);
      Ratio   : Float;
      Current : Point := (0, 0);
      Prev    : Unsigned_32;
      FG      : constant UInt32 := Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                       Foreground);
      Blk     : constant UInt32 := Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                       Black);

      procedure Internal_Draw_Line
        (X0, Y0, X1, Y1 : Natural;
         Width          : Positive);

      procedure Internal_Draw_Line
        (X0, Y0, X1, Y1 : Natural;
         Width          : Positive)
      is
      begin
         Draw_Line (Buffer,
                    (Area.Position.X + Natural (Float (X0) * Ratio),
                     Area.Position.Y + Y0),
                    (Area.Position.X + Natural (Float (X1) * Ratio),
                     Area.Position.Y + Y1),
                    Foreground,
                    Width,
                    Fast);
      end Internal_Draw_Line;

      procedure Draw_Glyph is new Hershey_Fonts.Draw_Glyph
        (Internal_Draw_Line);

   begin
      if Length > Area.Width then
         Ratio := Float (Area.Width) / Float (Length);
      else
         Ratio := 1.0;
         Current.X := (Area.Width - Length) / 2;
      end if;

      for C of Msg loop
         Draw_Glyph
           (Fnt    => Font,
            C      => C,
            X      => Current.X,
            Y      => Current.Y,
            Height => Area.Height,
            Bold   => Bold);
      end loop;

      if Outline and then Area.Height > 40 then
         for Y in Area.Position.Y + 1 .. Area.Position.Y + Area.Height loop
            Prev := Buffer.Pixel (Area.Position.X, Y);
            if Prev = FG then
               Buffer.Set_Pixel (Area.Position.X, Y, Black);
            end if;

            for X in Area.Position.X + 1 .. Area.Position.X + Area.Width loop
               declare
                  Col : constant Unsigned_32 := Buffer.Pixel (X, Y);
                  Top : constant Unsigned_32 := Buffer.Pixel (X, Y - 1);
               begin

                  if Prev /= FG
                    and then Col = FG
                  then
                     Buffer.Set_Pixel (X, Y, Blk);

                  elsif Prev = FG
                    and then Col /= FG
                  then
                     Buffer.Set_Pixel (X - 1, Y, Blk);

                  elsif Top /= FG
                    and then Top /= Blk
                    and then Col = FG
                  then
                     Buffer.Set_Pixel (X, Y, Blk);

                  elsif Top = FG
                    and then Col /= FG
                  then
                     Buffer.Set_Pixel (X, Y - 1, Blk);
                  end if;

                  Prev := Col;
               end;
            end loop;
         end loop;
      end if;
   end Draw_String;

   ---------------
   -- Draw_Line --
   ---------------

   procedure Draw_Line
     (Buffer      : in out Bitmap_Buffer'Class;
      Start, Stop : Point;
      Hue         : Bitmap_Color;
      Thickness   : Natural := 1;
      Fast        : Boolean := True)
   is
      Col : constant Unsigned_32 := Bitmap_Color_To_Word (Buffer.Color_Mode,
                                                          Hue);
   begin
      Draw_Line (Buffer, Start, Stop, Col, Thickness, Fast);
   end Draw_Line;

   --  http://rosettacode.org/wiki/Bitmap/Bresenham%27s_line_algorithm#Ada
   ---------------
   -- Draw_Line --
   ---------------

   procedure Draw_Line
     (Buffer      : in out Bitmap_Buffer'Class;
      Start, Stop : Point;
      Hue         : Unsigned_32;
      Thickness   : Natural := 1;
      Fast        : Boolean := True)
   is
      DX     : constant Float := abs Float (Stop.X - Start.X);
      DY     : constant Float := abs Float (Stop.Y - Start.Y);
      Err    : Float;
      X      : Natural := Start.X;
      Y      : Natural := Start.Y;
      Step_X : Integer := 1;
      Step_Y : Integer := 1;

      procedure Draw_Point (P : Point) with Inline;

      ----------------
      -- Draw_Point --
      ----------------

      procedure Draw_Point (P : Point) is
      begin
         if Thickness /= 1 then
            if not Fast then
               Fill_Circle (Buffer,
                            Color  => Hue,
                            Center_X => P.X,
                            Center_Y => P.Y,
                            Radius => Thickness / 2);
            else
               Buffer.Fill_Rect
                 (Hue,
                  P.X - (Thickness / 2),
                  P.Y - (Thickness / 2),
                  Thickness,
                  Thickness);
            end if;
         else
            Buffer.Set_Pixel (P.X, P.Y, Hue);
         end if;
      end Draw_Point;

   begin
      if Start.X > Stop.X then
         Step_X := -1;
      end if;

      if Start.Y > Stop.Y then
         Step_Y := -1;
      end if;

      if DX > DY then
         Err := DX / 2.0;
         while X /= Stop.X loop
            Draw_Point ((X, Y));
            Err := Err - DY;
            if Err < 0.0 then
               Y := Y + Step_Y;
               Err := Err + DX;
            end if;
            X := X + Step_X;
         end loop;
      else
         Err := DY / 2.0;
         while Y /= Stop.Y loop
            Draw_Point ((X, Y));
            Err := Err - DX;
            if Err < 0.0 then
               X := X + Step_X;
               Err := Err + DY;
            end if;
            Y := Y + Step_Y;
         end loop;
      end if;

      Draw_Point ((X, Y));
   end Draw_Line;

   --  http://rosettacode.org/wiki/Bitmap/B%C3%A9zier_curves/Cubic
   ------------------
   -- Cubic_Bezier --
   ------------------

   procedure Cubic_Bezier
     (Buffer         : in out Bitmap_Buffer'Class;
      P1, P2, P3, P4 : Point;
      Hue            : Bitmap_Color;
      N              : Positive := 20;
      Thickness      : Natural := 1)
   is
      Points : array (0 .. N) of Point;
   begin
      for I in Points'Range loop
         declare
            T : constant Float := Float (I) / Float (N);
            A : constant Float := (1.0 - T)**3;
            B : constant Float := 3.0 * T * (1.0 - T)**2;
            C : constant Float := 3.0 * T**2 * (1.0 - T);
            D : constant Float := T**3;
         begin
            Points (I).X := Natural (A * Float (P1.X) +
                                    B * Float (P2.X) +
                                    C * Float (P3.X) +
                                    D * Float (P4.X));
            Points (I).Y := Natural (A * Float (P1.Y) +
                                    B * Float (P2.Y) +
                                    C * Float (P3.Y) +
                                    D * Float (P4.Y));
         end;
      end loop;
      for I in Points'First .. Points'Last - 1 loop
         Draw_Line (Buffer, Points (I), Points (I + 1), Hue,
                    Thickness => Thickness);
      end loop;
   end Cubic_Bezier;

end Bitmapped_Drawing;
