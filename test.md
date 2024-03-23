```rust
use printpdf::*;
use std::fs::File;
use std::io::BufWriter;
use std::io::Cursor;

fn main() {
    create();
}

fn create() {
    let (doc, page1, layer1) = PdfDocument::new("Example pdf", Mm(210.0), Mm(297.0), "Layer 1");
    let current_layer = doc.get_page(page1).get_layer(layer1);

    let mut font_reader =
        std::io::Cursor::new(include_bytes!("../assets/fonts/RobotoMedium.ttf").as_ref());
    let font = doc.add_external_font(&mut font_reader).unwrap();
    let black = Rgb::new(0.0 / 256.0, 071.0 / 256.0, 0.0 / 256.0, None);
    let gray = Rgb::new(128.0 / 256.0, 128.0 / 256.0, 128.0 / 256.0, None);
    let orange = Rgb::new(244.0 / 256.0, 67.0 / 256.0, 54.0 / 256.0, None);

    current_layer.use_text("Crypton Tech", 20.0, Mm(30.0), Mm(250.0), &font);
    current_layer.set_fill_color(Color::Rgb(gray.clone()));
    current_layer.use_text("INVOICE", 20.0, Mm(90.0), Mm(225.0), &font);

    // Company Contact section
    current_layer.begin_text_section();

    current_layer.set_font(&font, 12.0);
    current_layer.set_text_cursor(Mm(150.0), Mm(270.0));
    current_layer.set_line_height(15.0);
    current_layer.set_word_spacing(1000.0);
    current_layer.set_character_spacing(1.0);
    current_layer.set_fill_color(Color::Rgb(orange.clone()));

    current_layer.write_text("Contact", &font);
    current_layer.add_line_break();
    current_layer.set_fill_color(Color::Rgb(black.clone()));
    current_layer.write_text("Erode", &font);
    current_layer.add_line_break();
    current_layer.write_text("+91 1234567890", &font);
    current_layer.add_line_break();
    current_layer.write_text("email@crypton.co.in", &font);
    current_layer.add_line_break();
    current_layer.end_text_section();

    // Customer Contact section
    current_layer.begin_text_section();

    current_layer.set_font(&font, 12.0);
    current_layer.set_text_cursor(Mm(15.0), Mm(230.0));
    current_layer.set_line_height(15.0);
    current_layer.set_word_spacing(1000.0);
    current_layer.set_character_spacing(1.0);
    current_layer.set_fill_color(Color::Rgb(orange.clone()));

    current_layer.write_text("Name", &font);
    current_layer.add_line_break();
    current_layer.write_text("Contact", &font);
    current_layer.add_line_break();
    current_layer.set_fill_color(Color::Rgb(black.clone()));
    current_layer.write_text("Erode", &font);
    current_layer.add_line_break();
    current_layer.write_text("+91 1234567890", &font);
    current_layer.add_line_break();
    current_layer.write_text("email@crypton.co.in", &font);
    current_layer.add_line_break();
    current_layer.end_text_section();

    // Customer Contact section
    current_layer.begin_text_section();

    current_layer.set_font(&font, 12.0);
    current_layer.set_text_cursor(Mm(150.0), Mm(230.0));
    current_layer.set_line_height(15.0);
    current_layer.set_word_spacing(1000.0);
    current_layer.set_character_spacing(1.0);
    current_layer.set_fill_color(Color::Rgb(black.clone()));

    current_layer.write_text("Total due", &font);
    current_layer.add_line_break();
    current_layer.set_fill_color(Color::Rgb(black.clone()));
    current_layer.write_text("USD - $6570.00", &font);
    current_layer.add_line_break();
    current_layer.write_text("NO #1234567890", &font);
    current_layer.add_line_break();
    current_layer.write_text("Date: 22-03-2024", &font);
    current_layer.add_line_break();
    current_layer.end_text_section();

    let points1 = vec![
        (Point::new(Mm(10.0), Mm(30.0)), false),
        (Point::new(Mm(10.0), Mm(200.0)), false),
        (Point::new(Mm(200.0), Mm(200.0)), false),
        (Point::new(Mm(200.0), Mm(30.0)), false),
    ];

    // Is the shape stroked? Is the shape closed? Is the shape filled?
    let line1 = Line {
        points: points1.clone(),
        is_closed: true,
    };

    current_layer.set_outline_thickness(1.0);
    current_layer.add_line(line1);

    let points1 = vec![
        (Point::new(Mm(100.0), Mm(30.0)), false),
        (Point::new(Mm(100.0), Mm(200.0)), false),
    ];

    let line1 = Line {
        points: points1.clone(),
        is_closed: true,
    };

    current_layer.set_outline_thickness(1.0);
    current_layer.add_line(line1);

    let points1 = vec![
        (Point::new(Mm(135.0), Mm(30.0)), false),
        (Point::new(Mm(135.0), Mm(200.0)), false),
    ];

    let line1 = Line {
        points: points1.clone(),
        is_closed: true,
    };

    current_layer.set_outline_thickness(1.0);
    current_layer.add_line(line1);


    let points1 = vec![
        (Point::new(Mm(165.0), Mm(30.0)), false),
        (Point::new(Mm(165.0), Mm(200.0)), false),
    ];

    let line1 = Line {
        points: points1.clone(),
        is_closed: true,
    };

    current_layer.set_outline_thickness(1.0);
    current_layer.add_line(line1);

    // Customer Contact section
    current_layer.begin_text_section();

    current_layer.set_font(&font, 12.0);
    current_layer.set_text_cursor(Mm(15.0), Mm(200.0));
    current_layer.set_line_height(15.0);
    current_layer.set_word_spacing(1000.0);
    current_layer.set_character_spacing(1.0);
    current_layer.set_fill_color(Color::Rgb(orange.clone()));

    current_layer.write_text("Name", &font);
    current_layer.write_text("Contact", &font);
    current_layer.set_fill_color(Color::Rgb(black.clone()));
    current_layer.write_text("Erode", &font);
    current_layer.write_text("+91 1234567890", &font);
    current_layer.write_text("email@crypton.co.in", &font);
    current_layer.end_text_section();

    doc.save(&mut BufWriter::new(File::create("test_fonts.pdf").unwrap()))
        .unwrap();
}
```
