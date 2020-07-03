/**

This module defines constants or utilities that might be commonly useful
for different graphics extensions, such as pxgfx.

*/

module capsule.extension.graphics;

public:

/// 8x8 images representing ASCII characters
/// Encoding: Row-major, 1 bit per pixel, highest bit first and lowest last
static const ulong CapsuleGraphicsBitmap_null = 0x0000000000000000;
static const ulong CapsuleGraphicsBitmap_bell = 0x0c1e1e1e3f000c00;
static const ulong CapsuleGraphicsBitmap_bang = 0x0c1e1e0c0c000c00;
static const ulong CapsuleGraphicsBitmap_quote = 0x1b1b090000000000;
static const ulong CapsuleGraphicsBitmap_hash = 0x36367f367f363600;
static const ulong CapsuleGraphicsBitmap_dollar = 0x087e0b3e686b3e08;
static const ulong CapsuleGraphicsBitmap_percent = 0x2333180c06333100;
static const ulong CapsuleGraphicsBitmap_ampersand = 0x0e1b1b0e331b2e00;
static const ulong CapsuleGraphicsBitmap_apostrophe = 0x0c0c060000000000;
static const ulong CapsuleGraphicsBitmap_open_paren = 0x180c060606060c18;
static const ulong CapsuleGraphicsBitmap_close_paren = 0x060c181818180c06;
static const ulong CapsuleGraphicsBitmap_asterisk = 0x000c2d1e1e2d0c00;
static const ulong CapsuleGraphicsBitmap_plus = 0x00000c0c3f0c0c00;
static const ulong CapsuleGraphicsBitmap_comma = 0x00000000000c0c06;
static const ulong CapsuleGraphicsBitmap_hyphen = 0x000000003f000000;
static const ulong CapsuleGraphicsBitmap_period = 0x00000000000c0c00;
static const ulong CapsuleGraphicsBitmap_slash = 0x38181c0c0e060700;
static const ulong CapsuleGraphicsBitmap_0 = 0x1e333b3733331e00;
static const ulong CapsuleGraphicsBitmap_1 = 0x0c0e0c0c0c0c3f00;
static const ulong CapsuleGraphicsBitmap_2 = 0x1e33301e03033f00;
static const ulong CapsuleGraphicsBitmap_3 = 0x1e33301c30331e00;
static const ulong CapsuleGraphicsBitmap_4 = 0x30383c36333f3000;
static const ulong CapsuleGraphicsBitmap_5 = 0x3f031f3030331e00;
static const ulong CapsuleGraphicsBitmap_6 = 0x1e031f3333331e00;
static const ulong CapsuleGraphicsBitmap_7 = 0x3f3030180c0c0c00;
static const ulong CapsuleGraphicsBitmap_8 = 0x1e33331e33331e00;
static const ulong CapsuleGraphicsBitmap_9 = 0x1e33333e30331e00;
static const ulong CapsuleGraphicsBitmap_colon = 0x000c0c00000c0c00;
static const ulong CapsuleGraphicsBitmap_semicolon = 0x000c0c00000c0c06;
static const ulong CapsuleGraphicsBitmap_open_angle_bracket = 0x0000380e030e3800;
static const ulong CapsuleGraphicsBitmap_equals = 0x0000003f003f0000;
static const ulong CapsuleGraphicsBitmap_close_angle_bracket = 0x0000071c301c0700;
static const ulong CapsuleGraphicsBitmap_question = 0x1e3330180c000c00;
static const ulong CapsuleGraphicsBitmap_at = 0x1e333b3b3b031e00;
static const ulong CapsuleGraphicsBitmap_A = 0x1e33333f33333300;
static const ulong CapsuleGraphicsBitmap_B = 0x1f33331f33331f00;
static const ulong CapsuleGraphicsBitmap_C = 0x1e33030303331e00;
static const ulong CapsuleGraphicsBitmap_D = 0x0f1b333333331f00;
static const ulong CapsuleGraphicsBitmap_E = 0x3f03030f03033f00;
static const ulong CapsuleGraphicsBitmap_F = 0x3f33030f03030300;
static const ulong CapsuleGraphicsBitmap_G = 0x1e3303033b333e30;
static const ulong CapsuleGraphicsBitmap_H = 0x3333333f33333300;
static const ulong CapsuleGraphicsBitmap_I = 0x3f0c0c0c0c0c3f00;
static const ulong CapsuleGraphicsBitmap_J = 0x3c3030303030331e;
static const ulong CapsuleGraphicsBitmap_K = 0x331b0f070f1b3300;
static const ulong CapsuleGraphicsBitmap_L = 0x0303030303333f00;
static const ulong CapsuleGraphicsBitmap_M = 0x63777f6b63636300;
static const ulong CapsuleGraphicsBitmap_N = 0x3333373f3b333300;
static const ulong CapsuleGraphicsBitmap_O = 0x1e33333333331e00;
static const ulong CapsuleGraphicsBitmap_P = 0x1f33331f03030300;
static const ulong CapsuleGraphicsBitmap_Q = 0x1e333333331b0e3c;
static const ulong CapsuleGraphicsBitmap_R = 0x1f33331f0f1b3300;
static const ulong CapsuleGraphicsBitmap_S = 0x1e33031e30331e00;
static const ulong CapsuleGraphicsBitmap_T = 0x3f2d0c0c0c0c0c00;
static const ulong CapsuleGraphicsBitmap_U = 0x3333333333336e00;
static const ulong CapsuleGraphicsBitmap_V = 0x33333333331e0c00;
static const ulong CapsuleGraphicsBitmap_W = 0x6363636b7f776300;
static const ulong CapsuleGraphicsBitmap_X = 0x33331e0c1e333300;
static const ulong CapsuleGraphicsBitmap_Y = 0x3333331e0c0c0c00;
static const ulong CapsuleGraphicsBitmap_Z = 0x3f33180c06333f00;
static const ulong CapsuleGraphicsBitmap_open_square_bracket = 0x1e0606060606061e;
static const ulong CapsuleGraphicsBitmap_backslash = 0x07060e0c1c183800;
static const ulong CapsuleGraphicsBitmap_close_square_bracket = 0x1e1818181818181e;
static const ulong CapsuleGraphicsBitmap_caret = 0x0c1e332100000000;
static const ulong CapsuleGraphicsBitmap_underscore = 0x0000000000003f00;
static const ulong CapsuleGraphicsBitmap_backtick = 0x180c060000000000;
static const ulong CapsuleGraphicsBitmap_a = 0x00001e303e333e00;
static const ulong CapsuleGraphicsBitmap_b = 0x03031f3333331f00;
static const ulong CapsuleGraphicsBitmap_c = 0x00001e3303331e00;
static const ulong CapsuleGraphicsBitmap_d = 0x38303e3333333e00;
static const ulong CapsuleGraphicsBitmap_e = 0x00001e333f031e00;
static const ulong CapsuleGraphicsBitmap_f = 0x1e33030f03030300;
static const ulong CapsuleGraphicsBitmap_g = 0x00003e33333e301e;
static const ulong CapsuleGraphicsBitmap_h = 0x03031f3333333300;
static const ulong CapsuleGraphicsBitmap_i = 0x000c000e0c0c1e00;
static const ulong CapsuleGraphicsBitmap_j = 0x003000383030331e;
static const ulong CapsuleGraphicsBitmap_k = 0x0303331b0f1b3300;
static const ulong CapsuleGraphicsBitmap_l = 0x0e0c0c0c0c0c1800;
static const ulong CapsuleGraphicsBitmap_m = 0x0000377f6b6b6b00;
static const ulong CapsuleGraphicsBitmap_n = 0x00001d3333333300;
static const ulong CapsuleGraphicsBitmap_o = 0x00001e3333331e00;
static const ulong CapsuleGraphicsBitmap_p = 0x00001f33331f0303;
static const ulong CapsuleGraphicsBitmap_q = 0x00006e33333e3070;
static const ulong CapsuleGraphicsBitmap_r = 0x00001f3303030300;
static const ulong CapsuleGraphicsBitmap_s = 0x00003e031e301f00;
static const ulong CapsuleGraphicsBitmap_t = 0x000c0c3f0c0c0c18;
static const ulong CapsuleGraphicsBitmap_u = 0x0000333333336e00;
static const ulong CapsuleGraphicsBitmap_v = 0x00003333331e0c00;
static const ulong CapsuleGraphicsBitmap_w = 0x0000636b6b7f3600;
static const ulong CapsuleGraphicsBitmap_x = 0x0000331e0c1e3300;
static const ulong CapsuleGraphicsBitmap_y = 0x00003333333e301e;
static const ulong CapsuleGraphicsBitmap_z = 0x00003f180c063f00;
static const ulong CapsuleGraphicsBitmap_open_curly_brace = 0x180c0c060c0c0c18;
static const ulong CapsuleGraphicsBitmap_bar = 0x0c0c0c0c0c0c0c0c;
static const ulong CapsuleGraphicsBitmap_close_curly_brace = 0x060c0c180c0c0c06;
static const ulong CapsuleGraphicsBitmap_tilde = 0x0000263f19000000;

/// A box, as might be used to represent an unknown or invalid character
static const ulong CapsuleGraphicsBitmap_box = 0x003f212121213f00;

/// Array of 64-bit bitmaps representing ASCII characters
static const ulong[] CapsuleGraphicsAsciiBitmaps = [
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_bell,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_null,
    CapsuleGraphicsBitmap_bang,
    CapsuleGraphicsBitmap_quote,
    CapsuleGraphicsBitmap_hash,
    CapsuleGraphicsBitmap_dollar,
    CapsuleGraphicsBitmap_percent,
    CapsuleGraphicsBitmap_ampersand,
    CapsuleGraphicsBitmap_apostrophe,
    CapsuleGraphicsBitmap_open_paren,
    CapsuleGraphicsBitmap_close_paren,
    CapsuleGraphicsBitmap_asterisk,
    CapsuleGraphicsBitmap_plus,
    CapsuleGraphicsBitmap_comma,
    CapsuleGraphicsBitmap_hyphen,
    CapsuleGraphicsBitmap_period,
    CapsuleGraphicsBitmap_slash,
    CapsuleGraphicsBitmap_0,
    CapsuleGraphicsBitmap_1,
    CapsuleGraphicsBitmap_2,
    CapsuleGraphicsBitmap_3,
    CapsuleGraphicsBitmap_4,
    CapsuleGraphicsBitmap_5,
    CapsuleGraphicsBitmap_6,
    CapsuleGraphicsBitmap_7,
    CapsuleGraphicsBitmap_8,
    CapsuleGraphicsBitmap_9,
    CapsuleGraphicsBitmap_colon,
    CapsuleGraphicsBitmap_semicolon,
    CapsuleGraphicsBitmap_open_angle_bracket,
    CapsuleGraphicsBitmap_equals,
    CapsuleGraphicsBitmap_close_angle_bracket,
    CapsuleGraphicsBitmap_question,
    CapsuleGraphicsBitmap_at,
    CapsuleGraphicsBitmap_A,
    CapsuleGraphicsBitmap_B,
    CapsuleGraphicsBitmap_C,
    CapsuleGraphicsBitmap_D,
    CapsuleGraphicsBitmap_E,
    CapsuleGraphicsBitmap_F,
    CapsuleGraphicsBitmap_G,
    CapsuleGraphicsBitmap_H,
    CapsuleGraphicsBitmap_I,
    CapsuleGraphicsBitmap_J,
    CapsuleGraphicsBitmap_K,
    CapsuleGraphicsBitmap_L,
    CapsuleGraphicsBitmap_M,
    CapsuleGraphicsBitmap_N,
    CapsuleGraphicsBitmap_O,
    CapsuleGraphicsBitmap_P,
    CapsuleGraphicsBitmap_Q,
    CapsuleGraphicsBitmap_R,
    CapsuleGraphicsBitmap_S,
    CapsuleGraphicsBitmap_T,
    CapsuleGraphicsBitmap_U,
    CapsuleGraphicsBitmap_V,
    CapsuleGraphicsBitmap_W,
    CapsuleGraphicsBitmap_X,
    CapsuleGraphicsBitmap_Y,
    CapsuleGraphicsBitmap_Z,
    CapsuleGraphicsBitmap_open_square_bracket,
    CapsuleGraphicsBitmap_backslash,
    CapsuleGraphicsBitmap_close_square_bracket,
    CapsuleGraphicsBitmap_caret,
    CapsuleGraphicsBitmap_underscore,
    CapsuleGraphicsBitmap_backtick,
    CapsuleGraphicsBitmap_a,
    CapsuleGraphicsBitmap_b,
    CapsuleGraphicsBitmap_c,
    CapsuleGraphicsBitmap_d,
    CapsuleGraphicsBitmap_e,
    CapsuleGraphicsBitmap_f,
    CapsuleGraphicsBitmap_g,
    CapsuleGraphicsBitmap_h,
    CapsuleGraphicsBitmap_i,
    CapsuleGraphicsBitmap_j,
    CapsuleGraphicsBitmap_k,
    CapsuleGraphicsBitmap_l,
    CapsuleGraphicsBitmap_m,
    CapsuleGraphicsBitmap_n,
    CapsuleGraphicsBitmap_o,
    CapsuleGraphicsBitmap_p,
    CapsuleGraphicsBitmap_q,
    CapsuleGraphicsBitmap_r,
    CapsuleGraphicsBitmap_s,
    CapsuleGraphicsBitmap_t,
    CapsuleGraphicsBitmap_u,
    CapsuleGraphicsBitmap_v,
    CapsuleGraphicsBitmap_w,
    CapsuleGraphicsBitmap_x,
    CapsuleGraphicsBitmap_y,
    CapsuleGraphicsBitmap_z,
    CapsuleGraphicsBitmap_open_curly_brace,
    CapsuleGraphicsBitmap_bar,
    CapsuleGraphicsBitmap_close_curly_brace,
    CapsuleGraphicsBitmap_tilde,
    CapsuleGraphicsBitmap_null,
];
