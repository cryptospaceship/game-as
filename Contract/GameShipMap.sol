pragma solidity 0.4.25;

import "./Ownable.sol";
import "./GameLib.sol";

contract GameShipMap is Ownable {
    uint[64][64]    gameMap;
    uint size;
    uint sideSize;
    
   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function getInPosition(uint x, uint y) 
	    external 
	    view 
	    returns
        (
            uint id,
            uint grapheneDensity,
            uint metalDensity
        ) 
    {
        id = gameMap[x][y];
        (,grapheneDensity,metalDensity) = GameLib.getResourceDensity(x,y,size);
    }
    
   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function getStrategicMap(uint _x, uint _y) 
	    external 
	    view 
	    returns(uint[51])
    {
        uint[51] memory ret;
        uint x;
        uint y; 
        uint i;
        uint j;

        if ( _x + 3 < sideSize && _x > 3 ) {
            x = _x - 3;
        } else {
            if ( _x + 3 >= sideSize )
                x = sideSize - 7;
            else
                x = 0;                
        }

        if ( _y + 3 < sideSize && _y > 3 ) {
            y = _y - 3;
        } else {
            if ( _y + 3 >= sideSize )
                y = sideSize - 7;
            else
                y = 0;
        }
        
        for ( i = 0; i < 7; i++ ) {
            for ( j = 0; j < 7; j++ ) { 
                ret[i*7+j] = gameMap[i+x][j+y];
            }
        }
        ret[49] = x;
        ret[50] = y;
        return ret;
    }
    

   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function unsetInMapPosition(uint x, uint y) 
	    internal 
	    returns(uint _id) 
    {
        _id = gameMap[x][y];
        gameMap[x][y] = 0;
    } 
    
   /*
    * @title Get in Position
    * @dev 
    * @param x Axis X(uint)
    * @param y Axis Y(uint)
    * @return Id of the object or 0 
    */
    function setInMapPosition(uint _id, uint x, uint y)
	    internal 
	    returns(uint,uint)
    {
        require(x < sideSize && y < sideSize && gameMap[x][y] == 0);

        gameMap[x][y] = _id;    
        return (x,y);
    }
	
    function changeMapSize(uint s)
        internal
    {
        size = s * s;
        sideSize = s;
    }

    function getMapPosition(uint x, uint y)
        internal
        view
        returns(uint)
    {
        return gameMap[x][y];
    }
}
