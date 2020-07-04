/**

This module implements templates that can be used to check if one
input is in fact an instantiation of another template.

*/

module capsule.meta.templateof;

public:

enum bool isTemplateOf(alias T: Base!Args, alias Base, Args...) = true;

enum bool isTemplateOf(T: Base!Args, alias Base, Args...) = true;

enum bool isTemplateOf(T, alias Base) = false;

enum bool isTemplateOf(T, Base) = false;
