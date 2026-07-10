global with sharing class navigationLinkSetPicklist
extends VisualEditor.DynamicPickList {

    global override VisualEditor.DataRow getDefaultValue() {

        return new VisualEditor.DataRow(
            'Main Navigation',
            'Main Navigation'
        );
    }

    global override VisualEditor.DynamicPickListRows getValues() {

        VisualEditor.DynamicPickListRows rows =
            new VisualEditor.DynamicPickListRows();

        Set<String> addedLabels = new Set<String>();

        rows.addRow(
            new VisualEditor.DataRow(
                'Main Navigation',
                'Main Navigation'
            )
        );
        addedLabels.add('Main Navigation');

        for (
            NavigationLinkSet nav :
            [
                SELECT MasterLabel
                FROM NavigationLinkSet
                ORDER BY MasterLabel
            ]
        ) {
            if (addedLabels.contains(nav.MasterLabel)) {
                continue;
            }

            rows.addRow(
                new VisualEditor.DataRow(
                    nav.MasterLabel,
                    nav.MasterLabel
                )
            );
            addedLabels.add(nav.MasterLabel);
        }

        return rows;
    }
}