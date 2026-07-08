// ============================================================
//  Parametric Disc Golf Disc  —  disc.scad
// ============================================================
//  Punch in the four official PDGA measurements (diameter,
//  height, rim depth, rim width) for any approved mold, then
//  tune the shape-character sliders to match its silhouette.
//
//  Preset numbers for 28 famous molds live in disc.json
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
// Print-ready flat top: the entire top becomes a perfect plane (dome and shoulder_roll ignored) and the model is oriented top-down, ready to print without supports
flat_top = false;
// Flat-top only: minimum shoulder steepness in degrees from horizontal. The round shoulder is clamped to this chamfer so it prints cleanly top-down (overhang = 90 minus this). 45 is safe everywhere; drop toward 35 if your printer/cooling handles shallow overhangs and you want more of the round shoulder back
flat_top_chamfer = 45; // [30:1:60]
// 0 = flat top, 1 = very domey (ignored when flat_top is on)
dome = 0.45; // [0:0.01:1]
// Rolls the dome smoothly over the shoulder: 0 = flat shoulder band, 1 = continuous rollover into the nose (no effect on flat tops)
shoulder_roll = 0.35; // [0:0.01:1]
// Parting line: height of the widest point as a fraction of disc height (Paradox ~0.15, most discs 0.3-0.5, Tilt ~0.8)
nose_height = 0.35; // [0.05:0.01:0.9]
// 0 = blunt rounded nose (putter), 1 = sharp aerodynamic nose (driver)
nose_sharpness = 0.7; // [0:0.01:1]
// Underside of the wing: -1 = concave undercut (driver), 0 = straight, 1 = convex rounded (putter)
wing_shape = -0.25; // [-1:0.01:1]
// Width of the flat resting land on the rim bottom
bottom_land = 3.0; // [1:0.1:8]
// Bead radius on inner-bottom of rim (0 = beadless)
bead = 0.0; // [0:0.1:2.5]
// Direction the bead protrudes: 0 = straight down from the rim bottom (typical), 90 = inward from the wall
bead_angle = 0; // [0:1:90]
// Flight plate thickness at center
plate_thickness = 2.0; // [1.2:0.05:4]
// Inner rim wall lean, degrees outward at the bottom
inner_wall_draft = 2.0; // [0:0.5:10]
// Fillet where inner wall meets flight plate: spread along the plate underside (mm)
wall_fillet = 3.0; // [0:0.1:6]
// How far the same fillet reaches down the inner wall (mm)
wall_fillet_height = 3.0; // [0:0.1:8]

/* [Weight Estimate] */
// g/cm^3 — TPU 1.21, PETG 1.27, PLA 1.24, ABS 1.04, PP 0.90
density = 1.21; // [0.8:0.01:1.5]
// Printed weight / theoretical solid. Even "100% infill" prints run a few percent light (micro-voids, slight underextrusion); calibrated from a real PLA test print: 167 g measured vs 178.4 g theoretical = 0.936
print_factor = 0.94; // [0.8:0.01:1]

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
        land = bottom_land, bd = bead, ba = bead_angle, pt = plate_thickness,
        draft = inner_wall_draft, fil = wall_fillet, filh_in = wall_fillet_height,
        ft = flat_top, fc = flat_top_chamfer, n = curve_steps) =
    let (
        R        = D / 2,
        r_in     = R - RW,                     // inner rim wall radius (at top of wall)
        z_nose   = H * nh,                     // height of widest point
        z_S      = min(RD + pt, H),            // shoulder height (plate top at the rim)
        // flat_top: the entire top is a perfect plane at z = H (dome and
        // shoulder_roll ignored; the dome region is filled solid). The
        // underside keeps its rim_depth geometry, so only the top changes.
        z_top    = ft ? H : z_S,
        flat     = _lerp(0.80, 0.30, dm),      // how long the dome stays high
        // --- plate top: center (0,H) -> shoulder (r_in, z_top) ---
        // shoulder_roll tilts the shared tangent at S downward (angle sa), so
        // the dome rolls continuously over the shoulder instead of flattening
        // into a brim (which leaves a visible curvature crease). sa fades out
        // as the dome height approaches zero: flat tops keep a flat shoulder.
        sa   = sr * 22 * min(1, (H - z_top) / 2.5),
        tilt = min(0.15 * r_in * sin(sa), 0.8 * (H - z_top)),
        T  = [0, H],
        S  = [r_in, z_top],
        t1 = [flat * r_in, H],
        t2 = [r_in - 0.15 * r_in * cos(sa), z_top + tilt],
        // --- shoulder -> nose (R, z_nose), spans the rim width ---
        N  = [R, z_nose],
        nose_r = (z_top - z_nose) * _lerp(0.65, 0.12, ns),
        shoff = _lerp(0.30, 0.55, 1 - ns) * RW,
        // Flat-top mode: the shoulder departs the plate at the chamfer angle
        // and steepens continuously to the vertical nose - a smooth convex
        // shoulder in which every point is printable, instead of a flat
        // bevel. (The cone clamp below stays as a safety net; a convex
        // curve falls below its departure tangent, so it rarely engages.)
        da  = ft ? fc : sa,
        sh1 = [r_in + shoff * cos(da), z_top - shoff * sin(da)],  // same tangent as t2
        sh2 = [R, z_nose + nose_r],            // vertical arrival just above nose
        // --- wing underside: nose (R, z_nose) -> land edge ---
        // With a bead, the land floats `lift` above the resting plane: the
        // bead ring hangs below the surrounding rim bottom and is what the
        // disc actually rests on (z=0 stays the resting plane).
        r_wall_b = r_in + tan(draft) * RD,     // wall radius at the bottom (drafted)
        land_out = r_wall_b + land,
        lift = bd > 0 ? 0.8 * bd * cos(ba) : 0,
        B1 = [land_out, lift],
        s1 = _lerp2(N, B1, 1/3),               // straight-chord controls
        s2 = _lerp2(N, B1, 2/3),
        v1 = [R, z_nose * (1 - _lerp(0.35, 0.65, 1 - ns))],  // convex (blunt) controls
        v2 = [land_out + 0.6 * (R - land_out), lift],
        w1 = _lerp2(s1, ws >= 0 ? v1 : [2*s1[0] - v1[0], 2*s1[1] - v1[1]], abs(ws)),
        w2 = _lerp2(s2, ws >= 0 ? v2 : [2*s2[0] - v2[0], 2*s2[1] - v2[1]], abs(ws)),
        // --- bottom land, bead, inner rim wall ---
        // Bead: a circular lobe (radius 0.85*bd) tangent to the resting plane;
        // bead_angle sets its protrusion direction. 0 deg: the lobe hangs
        // straight down from the rim bottom at the wall line (photos of
        // Judge/Wizard-style beads); 90 deg: it bulges inward past the wall
        // (patent fig. 17 style). z=0 is always the bead bottom / contact
        // ring; the land floats `lift` above it. The outline follows the
        // circle from the land, under the lobe, up to the wall joint.
        rb   = 0.85 * bd,
        Cx   = r_wall_b - bd * sin(ba) + rb,   // apex sits bd*sin(ba) inside the wall
        Cz   = rb,
        xj   = min(Cx + sqrt(max(0, rb*rb - (rb - lift)*(rb - lift))), land_out - 0.3),
        th_L = -acos(min(1, max(-1, (xj - Cx) / rb))),           // land-side joint
        z_j  = Cz + sqrt(max(0, rb*rb - (Cx - r_wall_b)*(Cx - r_wall_b))),
        th_W = atan2(z_j - Cz, r_wall_b - Cx) - 360,             // wall joint (clockwise)
        bead_pts = bd > 0
            ? [for (t = [0:24]) let (th = th_L + (th_W - th_L) * t / 24)
                  [Cx + rb * cos(th), Cz + rb * sin(th)]]
            : [[r_wall_b, 0]],
        // --- flight plate underside ---
        // The underside meets the shoulder at zU = z_S - pt, so the plate
        // keeps ~full thickness all the way out. The wall fillet then rounds
        // the cavity corner by curving DOWN into the wall (adding material),
        // never up into the plate.
        zU   = z_S - pt,
        filc = max(0, min(fil, 0.8 * RW)),     // spread along the underside
        filh = max(0, min(filh_in,             // reach down the wall
                          zU - (bd > 0 ? 2*bd : 0) - 1)),
        has_fil = filc > 0.01 || filh > 0.01,
        // G1 fillet: tangent-matches the drafted wall at W and the underside
        // launch angle at F. The underside leaves the corner at the same
        // shoulder-roll angle sa as the plate top, so thickness stays uniform
        // and the corner flows instead of forcing a right angle.
        W  = [r_in, zU - filh],                // top of the straight inner wall
        q1 = [r_in - 0.5*filh*sin(draft), zU - filh + 0.5*filh*cos(draft)],
        F  = [r_in - filc, zU],                // fillet lands on the underside
        q2 = [F[0] + 0.5*filc*cos(sa), zU - 0.5*filc*sin(sa)],
        C  = [0, H - pt],
        f1m = 0.15 * (r_in - filc),            // sa=0 reduces to the old horizontal start
        f1 = [F[0] - f1m*cos(sa), min(zU + f1m*sin(sa), H - pt)],
        f2 = [flat * r_in, H - pt]
    )
    concat(
        bezpts(T, t1, t2, S, n),               // plate top (dome)
        // Flat-top chamfer: the shoulder curve leaves the flat plane
        // horizontally, which is unprintable top-down (90 deg overhang at
        // the plate). Clamp it under a cone descending at fc degrees from
        // the plate edge; the cone rejoins the original curve where it is
        // naturally steeper (the curve's slope only increases, so past the
        // crossing everything is steeper than fc). Floored at the parting
        // line so the widest point is never cut; rims too wide/low for the
        // cone to cross in time keep a flat ring there - the designer
        // warns when that happens.
        ft ? [for (p = bezpts_tail(S, sh1, sh2, N, n))
                 [p[0], min(p[1], max(H - (p[0] - r_in) * tan(fc), z_nose))]]
           : bezpts_tail(S, sh1, sh2, N, n),   // shoulder down to nose
        bezpts_tail(N, w1, w2, B1, n),         // wing underside
        bead_pts,                              // land inner edge / bead lobe
        [W],                                   // inner rim wall
        has_fil ? bezpts_tail(W, q1, q2, F, 12) : [],      // corner fillet
        bezpts_tail(has_fil ? F : W, f1, f2, C, n)         // flight plate underside
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
weight_g   = volume_mm3 * density * print_factor / 1000;

// ---- Flight number estimate (same math as designer.html) ----
// Least-squares fits on the 28 PDGA-verified presets in disc.json, extreme
// discs (Tilt, Paradox, Roadrunner) weighted 1+0.6*|value| so the stability
// scale spans the real range (LOOCV MAE: speed 0.56, glide 0.78, turn 0.75,
// fade 0.69). nose_height is the parting line — the dominant stability
// driver. See README for method and sources.
function _clamp(v, lo, hi) = min(hi, max(lo, v));
// flat_top fills the dome region: no camber, dome-effect zero
_domeH = flat_top ? 0 : max(0, height - rim_depth - plate_thickness);
_dome  = flat_top ? 0 : dome;
est_speed = _clamp(-5.386 + 0.7475*rim_width, 1, 14.5);
est_glide = _clamp( 5.249 + 0.151*_domeH + 0.086*rim_width
                   - 0.434*(100*rim_depth/diameter), 1, 7);
est_turn  = _clamp(-8.869 - 1.954*_dome + 8.935*nose_height
                   + 3.095*wing_shape + 0.289*rim_width, -5, 1.5);
est_fade  = _clamp(-4.554 + 0.243*rim_width + 8.955*nose_height
                   - 2.395*_dome, 0, 6);
echo(str("Estimated flight numbers: ",
    round(est_speed*2)/2, " / ", round(est_glide*2)/2, " / ",
    round(est_turn*2)/2,  " / ", round(est_fade*2)/2,
    "  (speed/glide/turn/fade, +-0.6-0.9)"));

// PDGA legality (PDGA Technical Standards — see README for sources)
pdga_max_weight = min(8.3 * diameter / 10, 200);
rim_depth_ratio = 100 * rim_depth / diameter;   // must be 5%..12%
inside_rim_d    = diameter - 2 * rim_width;     // must be >= 158 mm
echo(str("=== Disc: D=", diameter, "mm H=", height, "mm rimDepth=", rim_depth,
         "mm rimWidth=", rim_width, "mm ==="));
echo(str("Estimated solid volume: ", round(volume_mm3 / 100) / 10, " cm^3"));
echo(str("Estimated printed weight @ ", density, " g/cm^3 x ", print_factor,
         " print factor: ", round(weight_g * 10) / 10, " g"));
if (flat_top) echo("flat_top: model is oriented top-down, ready to print without supports");
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

// flat_top exports the disc top-down (top plane on z=0), so the STL drops
// into the slicer print-ready — no rotation, no supports.
module disc_oriented() {
    if (flat_top)
        translate([0, 0, height]) rotate([180, 0, 0]) disc();
    else
        disc();
}

if (cross_section)
    difference() {
        disc_oriented();
        translate([-diameter, -2*diameter, -1])
            cube([2*diameter, 2*diameter, height + 2]);
    }
else
    disc_oriented();
