module config;


public import config.config :   Config, Option, ConfigException,
                                InconsistentConfigState, InvalidConfigInput;

public import config.setting :  Setting, ScalarSetting, AggregateSetting,
                                ArraySetting, ListSetting, GroupSetting,
                                Type, IntegerFormat;