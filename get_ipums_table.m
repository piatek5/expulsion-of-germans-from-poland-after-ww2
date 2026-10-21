function tab_ipums = get_ipums_table(tab, bridge, shapes_ipums)
    % Łączenie spisu z mostem
    T_temp = innerjoin(tab, bridge, ...
        'LeftKeys', 'county_id', 'RightKeys', 'census_id');
    % Łączenie poprzedniego wyniku z IPUMS
    tab_ipums = innerjoin(T_temp, shapes_ipums(:, {'Shape', 'KREIS_KENN'}), ...
        'LeftKeys', 'ipums_id', 'RightKeys', 'KREIS_KENN');
    % Przesunięcie "Shape" na początek (dla readgeotable)
    tab_ipums = movevars(tab_ipums, 'Shape', 'Before', 1);
end