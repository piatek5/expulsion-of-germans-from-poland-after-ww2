function tab = add_lindau(tab)
    mask_bayern = tab.county_name == 'Bayern';
    mask_lindau = tab.county_name == 'Kreis Lindau (Bodensee)';

    num_vars = vartype('numeric');

    tab(mask_bayern, num_vars) = ...
        tab(mask_bayern, num_vars) + tab(mask_lindau, num_vars);
end