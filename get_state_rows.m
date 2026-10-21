function state_tab = get_state_rows(tab, state_names)
%GET_STATE_ROWS Select state-level rows from a census table.
    idx = zeros(numel(state_names), 1);

    for i = 1:numel(state_names)
        i_row = find(tab.county_name == state_names{i}, 1);

        if isempty(i_row)
            error('State "%s" not found in the table.', state_names{i});
        end

        idx(i) = i_row;
    end

    state_tab = tab(idx, :);
end
