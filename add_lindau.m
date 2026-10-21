function tab = add_lindau(tab)
%ADD_LINDAU Add "Kreis Lindau (Bodensee)" to the Bayern state total.

    mask_bayern = tab.county_name == 'Bayern';
    mask_lindau = tab.county_name == 'Kreis Lindau (Bodensee)';

    num_vars = vartype('numeric');

    tab(mask_bayern, num_vars) = ...
        tab(mask_bayern, num_vars) + tab(mask_lindau, num_vars);
end
