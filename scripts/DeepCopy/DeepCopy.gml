#macro deep_copy_flag_arrays_shallow 1
#macro deep_copy_flag_structs_shallow 2
#macro deep_copy_flag_construtors_shallow 4
#macro deep_copy_flag_sequences_copyable 8
/*
MIT License

Copyright (c) 2020 MusNik

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/// @function                       deep_copy(ref)
/// @param {T} ref                  Thing to deep copy
/// @param {Real} [flags]           Optinal flags to specify function behaviour, see https://github.com/KeeVeeGames/DeepCopy.gml for more info
/// @returns {T}                    New array, or new struct, or new instance of the class, anything else (real / string / etc.) will be returned as-is
/// @description                    Returns a deep recursive copy of the provided array / struct / constructed struct
function deep_copy(ref, flags = 0) {
    var ref_new;
    
    if (is_array(ref)) {
        ref_new = array_create(array_length(ref));
        
        var length = array_length(ref_new);
        
        if (flags & deep_copy_flag_arrays_shallow == 0) {
            for (var i = 0; i < length; i++) {
                ref_new[i] = deep_copy(ref[i]);
            }
        } else {
            for (var i = 0; i < length; i++) {
                ref_new[i] = ref[i];
            }
        }
        
        return ref_new;
    }
    else if (is_struct(ref)) {
        if (is_method(ref)) {
            ref_new = ref;
            
            return ref_new;
        }
        
        if (flags & deep_copy_flag_sequences_copyable != 0 && sequence_exists(ref)) {
            ref_new = sequence_duplicate(ref);
            
            return ref_new;
        }
        
        ref_new = {};
        var is_constructed = false;
        
        var static_struct = static_get(ref);
        if (static_struct != undefined) {
            static_set(ref_new, static_struct);
            is_constructed = true;
        }
        
        var names = variable_struct_get_names(ref);
        var length = variable_struct_names_count(ref);
        
        if (flags & deep_copy_flag_structs_shallow == 0 && (!is_constructed || flags & deep_copy_flag_construtors_shallow == 0)) {
            for (var i = 0; i < length; i++) {
                var name = names[i];
                variable_struct_set(ref_new, name, deep_copy(variable_struct_get(ref, name)));
            }
        } else {
            for (var i = 0; i < length; i++) {
                var name = names[i];
                variable_struct_set(ref_new, name, variable_struct_get(ref, name));
            }
        }
        
        return ref_new;
    } else {
        return ref;
    }
}

// GMEdit hint
/// @hint deep_copy<T>(ref:T, ?flags:number)->T Returns a deep recursive copy of the provided array / struct / constructed struct