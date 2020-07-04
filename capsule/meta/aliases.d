/**

This module defines special template related to aliases and alias sequences.

*/

module capsule.meta.aliases;

public:

template Alias(T...) if(T.length == 1) {
    alias Alias = T[0];
}

template Aliases(T...){
    alias Aliases = T;
}
