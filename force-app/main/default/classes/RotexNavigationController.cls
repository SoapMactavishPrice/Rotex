public without sharing class RotexNavigationController {

    @AuraEnabled(cacheable=true)
    public static List<MenuItemWrapper>
    getMenuItems(String menuName) {

        List<MenuItemWrapper> results =
            new List<MenuItemWrapper>();

        try {

            NavigationLinkSet navMenu = [

                SELECT Id,
                       MasterLabel

                FROM NavigationLinkSet

                WHERE MasterLabel = :menuName

                LIMIT 1
            ];

            List<NavigationMenuItem> menuItems = [

                SELECT Id,
                       Label,
                       Target,
                       Type,
                       Position

                FROM NavigationMenuItem

                WHERE NavigationLinkSetId = :navMenu.Id

                ORDER BY Position
            ];

            Integer index = 0;

            for (
                NavigationMenuItem navItem
                : menuItems
            ) {

                MenuItemWrapper wrap =
                    new MenuItemWrapper();

                wrap.id =
                    String.valueOf(index);

                wrap.label =
                    navItem.Label;

                wrap.publicLabel =
                    navItem.Label;

                if (
                    navItem.Target != null
                ) {

                    if (
                        navItem.Target.startsWith('/')
                    ) {

                        wrap.target =
                            navItem.Target;

                    } else {

                        wrap.target =
                            '/' +
                            navItem.Target;
                    }

                } else {

                    wrap.target = '/';
                }

                wrap.type =
                    navItem.Type;

                if (
                    navItem.Label != null &&
                    navItem.Label.toLowerCase()
                    == 'leads'
                ) {

                    wrap.badge = 2;
                }

                results.add(wrap);

                index++;
            }

        } catch (Exception e) {

            throw new AuraHandledException(
                e.getMessage()
            );
        }

        return results;
    }

    public class MenuItemWrapper {

        @AuraEnabled
        public String id;

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String publicLabel;

        @AuraEnabled
        public String target;

        @AuraEnabled
        public String type;

        @AuraEnabled
        public Integer badge;
    }
}