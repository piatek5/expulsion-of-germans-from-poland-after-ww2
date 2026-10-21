function tab_ipums = get_ipums_table(tab, bridge, shapes_ipums)
%GET_IPUMS_TABLE Attach IPUMS county shapes to a census table.

    % Join census data with the bridge table
    T_temp = innerjoin(tab, bridge, ...
        'LeftKeys', 'county_id', 'RightKeys', 'census_id');
    % Join the result with IPUMS shapes
    tab_ipums = innerjoin(T_temp, shapes_ipums(:, {'Shape', 'KREIS_KENN'}), ...
        'LeftKeys', 'ipums_id', 'RightKeys', 'KREIS_KENN');
    % Move "Shape" to the first column for geoplot
    tab_ipums = movevars(tab_ipums, 'Shape', 'Before', 1);
end
