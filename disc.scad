// ============================================================
//  Parametric Disc Golf Disc  —  disc.scad
// ============================================================
//  Punch in the four official PDGA measurements (diameter,
//  height, rim depth, rim width) for any approved mold, then
//  tune the shape-character sliders to match its silhouette.
//
//  Preset numbers for 27 famous molds live in disc.json
//  (OpenSCAD Customizer parameter sets: Window > Customizer,
//  then pick a preset from the dropdown) and in README.md.
//
//  A companion web designer (designer.html) previews the
//  cross-section + estimated weight and emits these numbers.
//
//  Geometry: the half cross-section is built from four cubic
//  Bezier curves (top, wing underside, bead/inner wall, flight
//  plate underside) and revolved with rotate_extrude. The same
//  math is mirrored in designer.html, so what you preview there
//  is what prints here.
// ============================================================

/* [Key PDGA Measurements (mm)] */
// Outer diameter (PDGA "Diameter", cm x 10)
diameter = 211.0; // [200:0.5:225]
// Overall height at center (PDGA "Height")
height = 14.0; // [10:0.1:25]
// Bottom of rim to underside of flight plate at the rim (PDGA "Rim Depth")
rim_depth = 12.0; // [8:0.1:18]
// Outer edge to inside rim wall (PDGA "Rim Thickness")
rim_width = 22.0; // [8:0.1:26]

/* [Shape Character] */
// 0 = flat top, 1 = very domey
dome = 0.45; // [0:0.01:1]
// Rolls the dome smoothly over the shoulder: 0 = flat shoulder band, 1 = continuous rollover into the nose (no effect on flat tops)
shoulder_roll = 0.35; // [0:0.01:1]
// Height of the widest point (nose apex) as a fraction of disc height
nose_height = 0.35; // [0.1:0.01:0.7]
// 0 = blunt rounded nose (putter), 1 = sharp aerodynamic nose (driver)
nose_sharpness = 0.7; // [0:0.01:1]
// Underside of the wing: -1 = concave undercut (driver), 0 = straight, 1 = convex rounded (putter)
wing_shape = -0.25; // [-1:0.01:1]
// Width of the flat resting land on the rim bottom
bottom_land = 3.0; // [1:0.1:8]
// Bead radius on inner-bottom of rim (0 = beadless)
bead = 0.0; // [0:0.1:2.5]
// Flight plate thickness at center
plate_thickness = 2.0; // [1.2:0.05:4]
// Inner rim wall lean, degrees outward at the bottom
inner_wall_draft = 2.0; // [0:0.5:10]
// Fillet where inner wall meets flight plate
wall_fillet = 3.0; // [0:0.1:6]

/* [Weight Estimate] */
// g/cm^3 — TPU 1.21, PETG 1.27, PLA 1.24, ABS 1.04, PP 0.90
density = 1.21; // [0.8:0.01:1.5]

/* [Output] */
// Render only half the disc to inspect the cross-section
cross_section = false;
// Optional text engraved into the underside of the flight plate, centered (reads correctly looking at the disc bottom)
label_text = "";
// Engraved text size
label_size = 12; // [6:1:24]
// Engraving depth
label_depth = 0.4; // [0.2:0.05:1]
// Rotational smoothness (segments)
smoothness = 200; // [60:4:360]
// Points per Bezier curve
curve_steps = 48; // [12:4:96]

/* [Hidden] */
$fs = 0.4;
$fa = 2;

// ---------------- Bezier helpers ----------------
function _lerp(a, b, t) = a + (b - a) * t;
function _lerp2(p, q, t) = [_lerp(p[0], q[0], t), _lerp(p[1], q[1], t)];
function bez3(p0, p1, p2, p3, t) =
    let (u = 1 - t)
    [ u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0],
      u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1] ];
// n+1 points including both endpoints
function bezpts(p0, p1, p2, p3, n) = [for (i = [0:n]) bez3(p0, p1, p2, p3, i/n)];
// same but skipping the first point (avoids duplicates when chaining)
function bezpts_tail(p0, p1, p2, p3, n) = [for (i = [1:n]) bez3(p0, p1, p2, p3, i/n)];

// ---------------- Profile construction ----------------
// Coordinates: x = radius from spin axis, y = height above resting plane.
// The flight plate is built as an (approximately) uniform-thickness shell:
// its top meets the rim at the shoulder S = (r_in, rim_depth + plate_thickness),
// so dome height = height - rim_depth - plate_thickness falls out of the
// PDGA numbers themselves. The nose curve then spans only the rim width.
function disc_profile(
        D = diameter, H = height, RD = rim_depth, RW = rim_width,
        dm = dome, sr = shoulder_roll,
        nh = nose_height, ns = nose_sharpness, ws = wing_shape,
        land = bottom_land, bd = bead, pt = plate_thickness,
        draft = inner_wall_draft, fil = wall_fillet, n = curve_steps) =
    let (
        R        = D / 2,
        r_in     = R - RW,                     // inner rim wall radius (at top of wall)
        z_nose   = H * nh,                     // height of widest point
        z_S      = min(RD + pt, H),            // shoulder height (plate top at the rim)
        flat     = _lerp(0.80, 0.30, dm),      // how long the dome stays high
        // --- plate top: center (0,H) -> shoulder (r_in, z_S) ---
        // shoulder_roll tilts the shared tangent at S downward (angle sa), so
        // the dome rolls continuously over the shoulder instead of flattening
        // into a brim (which leaves a visible curvature crease). sa fades out
        // as the dome height approaches zero: flat tops keep a flat shoulder.
        sa   = sr * 22 * min(1, (H - z_S) / 2.5),
        tilt = min(0.15 * r_in * sin(sa), 0.8 * (H - z_S)),
        T  = [0, H],
        S  = [r_in, z_S],
        t1 = [flat * r_in, H],
        t2 = [r_in - 0.15 * r_in * cos(sa), z_S + tilt],
        // --- shoulder -> nose (R, z_nose), spans the rim width ---
        N  = [R, z_nose],
        nose_r = (z_S - z_nose) * _lerp(0.65, 0.12, ns),
        shoff = _lerp(0.30, 0.55, 1 - ns) * RW,
        sh1 = [r_in + shoff * cos(sa), z_S - shoff * sin(sa)],  // same tangent as t2
        sh2 = [R, z_nose + nose_r],            // vertical arrival just above nose
        // --- wing underside: nose (R, z_nose) -> land edge (land_out, 0) ---
        r_wall_b = r_in + tan(draft) * RD,     // wall radius at the bottom (drafted)
        land_out = r_wall_b + land,
        B1 = [land_out, 0],
        s1 = _lerp2(N, B1, 1/3),               // straight-chord controls
        s2 = _lerp2(N, B1, 2/3),
        v1 = [R, z_nose * (1 - _lerp(0.35, 0.65, 1 - ns))],  // convex (blunt) controls
        v2 = [land_out + 0.6 * (R - land_out), 0],
        w1 = _lerp2(s1, ws >= 0 ? v1 : [2*s1[0] - v1[0], 2*s1[1] - v1[1]], abs(ws)),
        w2 = _lerp2(s2, ws >= 0 ? v2 : [2*s2[0] - v2[0], 2*s2[1] - v2[1]], abs(ws)),
        // --- bottom land, bead, inner rim wall ---
        bead_pts = bd > 0
            ? [for (a = [270 : -15 : 90])      // semicircular bump into the cavity
                  [r_wall_b + bd * cos(a), bd + bd * sin(a)]]
            : [[r_wall_b, 0]],
        wall_lo = bd > 0 ? [r_wall_b, 2 * bd] : [r_wall_b, 0],
        // --- flight plate underside ---
        // The underside meets the shoulder at zU = z_S - pt, so the plate
        // keeps ~full thickness all the way out. The wall fillet then rounds
        // the cavity corner by curving DOWN into the wall (adding material),
        // never up into the plate.
        zU   = z_S - pt,
        filc = max(0, min(fil, zU - (bd > 0 ? 2*bd : 0) - 1, 0.8 * RW)),
        W  = [r_in, zU - filc],                // top of the straight inner wall
        q1 = [r_in, zU - 0.45 * filc],         // circular-arc approximation
        q2 = [r_in - 0.45 * filc, zU],
        F  = [r_in - filc, zU],                // fillet lands on the underside
        C  = [0, H - pt],
        f1 = [0.85 * (r_in - filc), zU],       // horizontal start: mirrors plate top
        f2 = [flat * r_in, H - pt]
    )
    concat(
        bezpts(T, t1, t2, S, n),               // plate top (dome)
        bezpts_tail(S, sh1, sh2, N, n),        // shoulder down to nose
        bezpts_tail(N, w1, w2, B1, n),         // wing underside
        bead_pts,                              // land inner edge / bead bump
        [wall_lo, W],                          // inner rim wall
        filc > 0.01 ? bezpts_tail(W, q1, q2, F, 12) : [],  // corner fillet
        bezpts_tail(filc > 0.01 ? F : W, f1, f2, C, n)     // flight plate underside
    );                                         // polygon closes C -> T along the axis

// ---------------- Weight estimate (Pappus) ----------------
function _shoelace(p) = sum([for (i = [0:len(p)-1])
    let (j = (i + 1) % len(p)) p[i][0]*p[j][1] - p[j][0]*p[i][1]]);
function _cx_num(p) = sum([for (i = [0:len(p)-1])
    let (j = (i + 1) % len(p))
    (p[i][0] + p[j][0]) * (p[i][0]*p[j][1] - p[j][0]*p[i][1])]);
function sum(v, i = 0) = i >= len(v) ? 0 : v[i] + sum(v, i + 1);

profile   = disc_profile();
area2     = _shoelace(profile);                 // 2x signed area
areaAbs   = abs(area2) / 2;
centroidX = _cx_num(profile) / (3 * area2);
volume_mm3 = 2 * PI * abs(centroidX) * areaAbs; // solid of revolution
weight_g   = volume_mm3 * density / 1000;

// PDGA legality (PDGA Technical Standards — see README for sources)
pdga_max_weight = min(8.3 * diameter / 10, 200);
rim_depth_ratio = 100 * rim_depth / diameter;   // must be 5%..12%
inside_rim_d    = diameter - 2 * rim_width;     // must be >= 158 mm
echo(str("=== Disc: D=", diameter, "mm H=", height, "mm rimDepth=", rim_depth,
         "mm rimWidth=", rim_width, "mm ==="));
echo(str("Estimated solid volume: ", round(volume_mm3 / 100) / 10, " cm^3"));
echo(str("Estimated weight @ ", density, " g/cm^3: ", round(weight_g * 10) / 10, " g"));
echo(str("PDGA max legal weight for this diameter: ", round(pdga_max_weight * 10) / 10, " g",
         weight_g > pdga_max_weight ? "  ** OVER LIMIT (print lighter: infill/density) **" : "  (OK)"));
if (diameter < 210)          echo("** PDGA: diameter under 21 cm minimum **");
if (rim_depth_ratio < 5)     echo("** PDGA: rim depth under 5% of diameter **");
if (rim_depth_ratio > 12)    echo("** PDGA: rim depth over 12% of diameter **");
if (rim_width > 26)          echo("** PDGA: rim width over 2.6 cm maximum **");
if (inside_rim_d < 158)      echo("** PDGA: inside rim diameter under 15.8 cm minimum **");
if (plate_thickness > 5)     echo("** PDGA: flight plate over 0.5 cm maximum **");
if (nose_sharpness > 0.9)    echo("NOTE: PDGA requires leading edge radius >= 1.6 mm — very sharp noses may fail the gauge");

// ---------------- Solid ----------------
module disc_solid() {
    rotate_extrude(angle = 360, $fn = smoothness)
        polygon(profile);
}

module disc() {
    // Engraving sits on the flight-plate underside at center. The underside
    // domes down away from center, so the cut starts 2 mm below the center
    // surface and reaches label_depth above it — engraved depth is
    // label_depth at center, slightly deeper where the dome falls away.
    difference() {
        disc_solid();
        if (label_text != "")
            translate([0, 0, height - plate_thickness - 2])
                linear_extrude(2 + label_depth)
                    mirror([1, 0])   // mirrored so it reads right from below
                        text(label_text, size = label_size,
                             halign = "center", valign = "center",
                             font = "Helvetica:style=Bold");
    }
}

if (cross_section)
    difference() {
        disc();
        translate([-diameter, -2*diameter, -1])
            cube([2*diameter, 2*diameter, height + 2]);
    }
else
    disc();
