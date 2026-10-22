function tab_ipums = get_ipums_table(tab, bridge, shapes_ipums, bridge_key)
%GET_IPUMS_TABLE Attach IPUMS county shapes to a census table.
%   BRIDGE_KEY is the bridge column matched with tab.county_id:
%   'census_id' (table 7 numbering, default) or 'census_id_tab6_16'.
    arguments
        tab table
        bridge table
        shapes_ipums table
        bridge_key (1,:) char = 'census_id'
    end

    % Join census data with the bridge table
    T_temp = innerjoin(tab, bridge, ...
        'LeftKeys', 'county_id', 'RightKeys', bridge_key);
    % Join the result with IPUMS shapes
    tab_ipums = innerjoin(T_temp, shapes_ipums(:, {'Shape', 'KREIS_KENN'}), ...
        'LeftKeys', 'ipums_id', 'RightKeys', 'KREIS_KENN');
    % Move "Shape" to the first column for geoplot
    tab_ipums = movevars(tab_ipums, 'Shape', 'Before', 1);
end
