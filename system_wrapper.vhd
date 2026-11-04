library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity system_wrapper is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        out_00    : out std_logic_vector(31 downto 0);
        out_01    : out std_logic_vector(31 downto 0);
        out_10    : out std_logic_vector(31 downto 0);
        out_11    : out std_logic_vector(31 downto 0);
        hw_cycles : out std_logic_vector(31 downto 0);
        sw_cycles : out std_logic_vector(31 downto 0);
        led0      : out std_logic;
        led1      : out std_logic
    );
end entity system_wrapper;

architecture rtl of system_wrapper is

    component system is
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            out_00    : out std_logic_vector(31 downto 0);
            out_01    : out std_logic_vector(31 downto 0);
            out_10    : out std_logic_vector(31 downto 0);
            out_11    : out std_logic_vector(31 downto 0);
            hw_cycles : out std_logic_vector(31 downto 0);
            sw_cycles : out std_logic_vector(31 downto 0);
            led0      : out std_logic;
            led1      : out std_logic
        );
    end component;

begin

    uut : system
        port map (
            clk       => clk,
            reset     => reset,
            out_00    => out_00,
            out_01    => out_01,
            out_10    => out_10,
            out_11    => out_11,
            hw_cycles => hw_cycles,
            sw_cycles => sw_cycles,
            led0      => led0,
            led1      => led1
        );

end architecture rtl;