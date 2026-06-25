public   with sharing class convertCurrencytowords {
    static String[] to_19 = new string[]{ 'zero', 'One',  'Two', 'Three', 'Four',  'Five',  'Six', 'Seven',
        'Eight', 'Nine', 'Ten',  'Eleven', 'Twelve', 'Thirteen',  
        'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen' };
            static String[] tens = new string[]{ 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'};
                static string[] denom = new string[]{ '',
                    'Thousand',   'Million',     'Billion',    'trillion',    'quadrillion',  
                    'quintillion', 's!xtillion',   'septillion',  'octillion',   'nonillion',  
                    'decillion',  'undecillion',   'duodecillion', 'tredecillion',  'quattuordecillion',  
                    's!xdecillion', 'septendecillion', 'octodecillion', 'novemdecillion', 'vigintillion' };
                        // convert a value < 100 to English.  
                        public static string convert_nn(integer val) {
                            if (val < 20)
                                return to_19[val];
                            if (val == 100)
                                return 'One Hundred';   
                            for (integer v = 0; v < tens.size(); v++) {
                                String dcap = tens[v];
                                integer dval = 20 + 10 * v;
                                if (dval + 10 > val) {
                                     if (Math.Mod(val,10) != 0)
                                        return dcap + ' ' + to_19[Math.Mod(val,10)];
                                    return dcap;
                                }    
                            }
                            return 'Should never get here, less than 100 failure';
                        }
    // convert a value < 1000 to english, special cased because it is the level that kicks   
    // off the < 100 special case. The rest are more general. This also allows you to  
    // get strings in the form of "forty-five hundred" if called directly.  
    public static String convert_nnn(integer val) {
        string word = '';
        integer rem = val / 100;
        integer mod = Math.mod(val,100);
        if (rem > 0) {
            word = to_19[rem] + ' Hundred and';
            if (mod > 0) {
                word += ' ';
            }
        }
        if (mod > 0) {
            word += convert_nn(mod);
        }
        return word;
    }
    public static String english_number(Decimal val) {
        if (val < 100) {
            return convert_nn(val.intValue());
        }
        if (val < 1000) {
            return convert_nnn(val.intValue());
        }
        for (integer v = 0; v < denom.size(); v++) {
            integer didx = v - 1;
            integer dval = (integer)Math.pow(1000, v);
            if (dval > val) {
                integer mod = (integer)Math.pow(1000, didx);
                integer l = (integer) val / mod;
                integer r = (integer) val - (l * mod);
                String ret = convert_nnn(l) + ' ' + denom[didx];
                if (r > 0) {
                    ret += ', ' + english_number(r);
                }
                return ret;
            }
        }
        return 'Should never get here, bottomed out in english_number';
    }


    //******************************************************************
    //                  Indian rupees by vishesh 23 sept 2020
    //******************************************************************

    static String[] units = new String[]{'Zero ','One ','Two ','Three ','Four ','Five ','Six ','Seven ','Eight ','Nine ','Ten ',
        'Eleven ','Twelve ','Thirteen ','Fourteen ','Fifteen ',
        'Sixteen ','Seventeen ','Eighteen ','Nineteen '};
            static String[] ten = new String[]{'','','Twenty ','Thirty ','Forty ','Fifty ','Sixty ','Seventy ','Eighty ','Ninety '};   
                public static String convert(Long i) {
                    if( i < 20)  {            
                        return units[integer.valueOf(i)];
                    }
                    if( i < 100) {
                        return ten[integer.valueOf(i)/10] + ((math.mod(i , 10) > 0)? '' + convert(math.mod(i , 10)):'');
                    }
                    if( i < 1000) {
                        return units[integer.valueOf(i)/100] + ' Hundred ' + ((math.mod(i , 100) > 0)?' ' + convert(math.mod(i , 100)):'');
                    }
                    if( i < 10000) {
                        return units[integer.valueOf(i)/1000] + ' Thousand ' + ((math.mod(i , 1000) > 0)?' ' + convert(math.mod(i , 1000)):'');
                    }
                    if( i < 100000) {
                        return convert(i / 1000) + ' Thousand ' + ((math.mod(i , 1000) > 0)? '' + convert(math.mod(i ,1000)):'') ;
                    }
                    if( i < 1000000) {
                        return units[integer.valueOf(i)/100000] + ' Lakh ' + ((math.mod(i , 100000) > 0)? '' + convert(math.mod(i ,100000)):'') ;
                    }
                    if( i < 10000000) {
                        return convert(i / 100000) + ' Lakh ' + ((math.mod(i , 100000) > 0)? '' + convert(math.mod(i ,100000)):'') ;
                    }
                    if(i < 100000000) {
                        return units[integer.valueOf(i)/10000000] + ' Crore ' + ((math.mod(i , 10000000) > 0)? '' + convert(math.mod(i , 10000000)):'') ;
                    }
                    if(i < 1000000000) {
                        return convert(i / 10000000) + 'Crore ' + ((math.mod(i , 10000000) > 0)? '' + convert(math.mod(i , 10000000)):'') ;
                    }
                    return convert(i / 1000000000) + ' Hundred Crore ' + ((math.mod(i , 1000000000) > 0) ? '' + convert(math.mod(i , 1000000000)):'') ;
                }
}