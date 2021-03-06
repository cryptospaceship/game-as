pragma solidity 0.4.24;

library GameLib {

    enum ResourceIndex {
        INDEX_UPGRADING,
        PANEL_1,
        PANEL_2,
        PANEL_3,
        PANEL_4,
        PANEL_5,
        PANEL_6,
        GRAPHENE,
        METAL
    }

    enum BuildingIndex {
        INDEX_UPGRADING,
        WAREHOUSE,
        HANGAR,
        CANNON
    }

    /**
     * @dev checkRange(): Comprueba si la nave principal se puede mover determinada
     * distancia
     * @param distance Distancia de movimiento
     * @param mode Modo de la nave principal. -> 0, 1, 2, 3
     * @param damage Daño de la nave de 0 a 100
     * @return inRange Booleano para saber si la nave se puede mover
     * @return lock Cantidad de bloques para el proximo movimiento
     */
    function checkRange(uint distance, uint mode, uint damage)
        external
        view
        returns(bool inRange, uint lock)
    {
        inRange = (distance <= getMovemmentByMode(mode) && distance != 0);
        if (inRange) 
            lock = lockMovemment(distance,mode,damage);
        else
            lock = 0;
    }

    /**
     * @dev checkCannonRange(): Comprueba si se puede disparar el cañon
     * @param distance Distancia de movimiento
     * @param level Nivel de cañon
     * @param shipDamage Daño de la nave principal
     * @return inRange: Si se puede disparar o no
     * @return damage: El daño que causa
     * @return cost: El costo de disparar el cañon
     * @return lock: Cantidad de de bloques para esperar el proximo disparo
     */
    function checkCannonRange(uint distance, uint level, uint shipDamage)
        external
        view
        returns(bool inRange, uint damage, uint cost, uint lock)
    {
        inRange = (level > 0 && (distance == 1 || (distance == 2 && level == 4)));
        if (inRange) {
            damage = getCannonDamage(level,distance);
            cost = getFireCannonCost();
            lock = 300; // Esto no me gusta
            if (shipDamage > 0) {
                lock = ((100 + shipDamage) * lock) / 100;
            }
            lock = block.number + lock;
        }
    }

    /**
     * @dev getProduction(): Calcula la produccion total de la nave
     * @param rLevel Array de 9 posiciones, con el nivel de cada panel 6 primera posiciones y las 
     * otras dos para el colector de grafeno y para el colector de metales
     * @param density Array de dos posisciones con la densidad de Graphene y Metal
     * @param eConsumption consumo de la nave
     * @param damage Daño de la nave principal (Afecta la produccion)
     * @return energy: Produccion total de energia
     * @return graphene: Produccion total de graphene
     * @return metal: Produccion total de metales
     */
    function getProduction(uint[9] rLevel, uint endUpgrade, uint[3] density, uint eConsumption, uint damage)
        external
        view
        returns(uint energy, uint graphene, uint metal)
    {
        if (endUpgrade > block.number)
            (energy,graphene,metal) = getProductionInternal(subResourceLevel(rLevel),density,eConsumption,damage);
        else
            (energy,graphene,metal) = getProductionInternal(rLevel,density,eConsumption,damage);        
    }

    /**
     * @dev getUnharvestResources(): Trae los recursos no cosechados
     * @param rLevel Array de 9 posiciones.
     *               0: Recurso que se esta ampliando
     *               1: Panel energia 1
     *               2: Panel energia 2
     *               3: Panel energia 3
     *               4: Panel energia 4
     *               5: Panel energia 5
     *               6: Panel energia 6
     *               7: Colector de Grapheno
     *               8: Colector de Metales
     * @param endUpgrade Numero de bloque en que la actualizacion de recursos va a finalizar
     * @param density Array de 3 posiciones con la densidad de recursos
     * @param eConsumption Consumo de enegia
     * @param damage Daño de la nave
     * @param lastHarvest Ultima vez que se "cosecho"
     */
    function getUnharvestResources(uint[9] rLevel, uint endUpgrade, uint[3] density, uint eConsumption, uint damage, uint lastHarvest)
        external
        view
        returns(uint energy, uint graphene, uint metal)
    {
        uint b = block.number;
        uint diff;
        uint e;
        uint g;
        uint m;

        energy = 0;
        graphene = 0;
        metal = 0;

        if (endUpgrade > b) {
            /*
             * En este punto todavia no se termino de hacer el upgrade
             * entonces quiere decir que hay un nivel que no hay que contemplarlo
             * que es el que se esta ampliando
             */
            (e,g,m) = getProductionInternal(subResourceLevel(rLevel),density,eConsumption,damage);
            diff = b - lastHarvest;

        } else {
            /*
             * Ya se termino de hacer el upgrade, y ahora hay que preguntarse cuando 
             * se termino de realizar el upgrade, antes del last harvest o despues
             */
            if (endUpgrade > lastHarvest) {
                /*
                 * El upgrade termino luego de la ultima "cosecha", entonces hay que calcular
                 * la produccion de dos maneras:
                 * 1- Desde la ultima "cosecha" hasta que termino el upgrade
                 * 2- Desde que termino el upgrade hasta el bloque actual
                 */

                // 1
                diff = endUpgrade - lastHarvest;
                (e,g,m) = getProductionInternal(subResourceLevel(rLevel),density,eConsumption,damage);
                energy = e * diff;
                graphene = g * diff;
                metal = m * diff;

                // 2
                diff = b - endUpgrade;
                (e,g,m) = getProductionInternal(rLevel,density,eConsumption,damage);
            }
            else {
                /*
                 * La ultima cosecha fue posterior a la cuando finalizo la construccion
                 */
                diff = b - lastHarvest;
                (e,g,m) = getProductionInternal(rLevel,density,eConsumption,damage);
            }
        }

        /*
         * Suma todos los recursos
         */ 
        energy = energy + (e * diff);
        graphene = graphene + (g * diff);
        metal = metal + (m * diff);
    }

    /**
     * @dev getProductionInternal(): Calcula la produccion total de la nave
     * @param rLevel Array de 8 posiciones, con el nivel de cada panel 6 primera posiciones y las 
     * otras dos para el colector de grafeno y para el colector de metales
     * @param density Array de dos posisciones con la densidad de Graphene y Metal
     * @param eConsumption consumo de la nave
     * @param damage Daño de la nave principal (Afecta la produccion)
     * @return energy: Produccion total de energia
     * @return graphene: Produccion total de graphene
     * @return metal: Produccion total de metales
     */
    function getProductionInternal(uint[9] rLevel, uint[3] density, uint eConsumption, uint damage)
        internal
        pure
        returns(uint energy, uint graphene, uint metal)
    {
        uint s;
        graphene = getProductionByLevel(rLevel[7]) * density[1];
        metal = getProductionByLevel(rLevel[8]) * density[2];

        if (damage != 0) {
            s = 100 - damage;
            graphene = s * graphene / 100;
            metal = s * metal / 100;
        }
        energy = getEnergyProduction(rLevel, eConsumption,damage);
    }

    function subResourceLevel(uint[9] level)
        internal
        pure
        returns(uint[9] ret)
    {
        ret = level;
        if (ret[0] != 0 )
            ret[ret[0]]--;
    }


    function getEnergyProduction(uint[9] panels, uint eConsumption, uint damage)
        internal
        pure
        returns(uint energy)
    {
        uint i;
        energy = 0;
        for (i = 1; i <= 6; i++) {
            energy = energy + (getProductionByLevel(panels[i]) * 2);
        }
        if (damage != 0) {
            energy = (100 - damage) * energy / 100;
        }
        energy = energy - eConsumption;
    }


    function portCombatCalc(uint[5] attacker, uint[5] dPoints, uint[5] dSize, uint distance)
        external
        view
        returns(bool combat, uint aRemain, uint[5] dRemain, uint lock)
    {
        (combat,lock) = checkFleetRange(distance, attacker[2], attacker[3], attacker[4],true);

        if (!combat)
            return;
        
        if (attacker[0] == 0) {
            aRemain = 0;
            dRemain = dSize;
            return;
        }

        (aRemain, dRemain) = portCombarCalcInternal(attacker[0],attacker[1],dPoints,dSize);
    }

    function shipCombatCalc(uint[5] attacker, uint[3] defender, uint distance)
        external
        view
        returns(bool combat, uint aRemain,uint dRemain, uint lock)  
    {
        (combat,lock) = checkFleetRange(distance, attacker[2], attacker[3], attacker[4], true);

        if (!combat)
            return;

        if (attacker[0] == 0) {
            aRemain = 0;
            dRemain = defender[1];
            return;
        }

        if ((defender[0] == 0 || defender[1] == 0) && (attacker[0] != 0 && attacker[1] != 0)) {
            aRemain = attacker[1];
            dRemain = 0;
            return;
        }

        (aRemain,dRemain) = shipCombatCalcInternal(attacker[0],attacker[1],attacker[3],defender[0],defender[1],defender[2]);
    }
    
    function getFleetEndProduction(uint size, uint hangarLevel, uint[9] rLevel, uint resourceEndUpgrade, uint eConsumption, uint damage)
        external
        view
        returns(bool,uint)
    {
        uint _block = block.number;
        uint batches = (size/48) + 1;
        uint ret;
        ret = batches * (5-hangarLevel) * 80;
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        if (resourceEndUpgrade > _block)
            return ((size <= getEnergyProduction(subResourceLevel(rLevel), eConsumption, damage)),(_block + ret));
        return ((size <= getEnergyProduction(rLevel, eConsumption, damage)),(_block + ret));
    }


    function validFleetDesign(uint _attack, uint _defense, uint _distance, uint _load, uint points)
        external
        pure
        returns(bool)
    {
        uint p = _attack + _defense + (_distance * 6) + (_load/80);
        return ( p <= points && p != 0);
    }


    function getFleetCost(uint _attack, uint _defense, uint _distance, uint _load, uint _points)
        external
        pure
        returns(
            uint fleetType,
            uint e, 
            uint g, 
            uint m
        ) 
    {
        uint points = _attack + _defense + (_distance * 6) + (_load/80);
        if ( points <= _points && points != 0) {
            e = (20*_attack) + (20 * _defense) + (20*(_distance*6)) + (20*(_load/80));
            g = (70*_defense) + (70*(_distance*6)) + (50*_attack) + (30*(_load/80));
            m = (70*_attack) + (70*(_load/80)) + (50*_defense) + (30*(_distance*6));
            fleetType = getFleetType(_attack,_defense,_distance,_load);
        }
        else {
            e = 0;
            g = 0;
            m = 0;
            fleetType = 0;
        }
    }

    function lockChangeMode(uint damage) 
        external
        view 
        returns(uint)
    {
        uint ret;
        ret = 280;
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }

    function getWarehouseLoadByLevel(uint level)
        external
        pure
        returns(uint)
    {
        uint24[5] memory warehouseStorage = [10000, 50000, 150000, 1300000, 16000000];
        return warehouseStorage[level];
    }
    
    function getUpgradeBuildingCost(uint _type, uint _level, uint damage) 
        external 
        view 
        returns(uint energy, uint graphene, uint metal, uint lock)
    {
        uint24[5] memory buildingCost = [0,5292,26168,120965,559164];
        /*
            Nuevos Costos Propuestos
            6933   Level 1
            32051  Level 2
            148156 Level 3
            684855 Level 4 
        */
        if (_type == 2) {
            energy = buildingCost[_level]*3;
            graphene = buildingCost[_level]*3;
            metal = buildingCost[_level]*3;
        } else {
            energy = buildingCost[_level];
            graphene = buildingCost[_level];
            metal = buildingCost[_level];
        }
        lock = lockUpgradeBuilding(_level,damage);
    }
    
    function getUpgradeResourceCost(uint _type, uint _level, uint damage) 
        external
        view
        returns(uint energy, uint graphene, uint metal, uint lock)
    {
        uint24[11] memory resourceCost = [0,1200,2520,5292,12171,26168,56263,120965,260076,559164,1202204];
        /*
            2584738 Level 11
            5557187 Level 12
            ----------------
            Nuevos Costos Propuestos
            1500    Level 1
            3225    Level 2
            6933    Level 3 
            14907   Level 4
            32051   Level 5
            68910   Level 6
            148156  Level 7    
            318537  Level 8
            684855  Level 9
            1472439 Level 10
            3165744 Level 11 <- Nuevos Niveles - Solo Energia 
            6806350 Level 12 <- Nuevos Niveles - Solo Energia
        */
        if (_type == 0) {
            energy = resourceCost[_level];
            graphene = resourceCost[_level]*2;
            metal = resourceCost[_level]*2;
        } else if (_type == 1) {
            energy = resourceCost[_level];
            graphene = resourceCost[_level]/2;
            metal = resourceCost[_level];
        } else if (_type == 2) {
            energy = resourceCost[_level];
            graphene = resourceCost[_level];
            metal = resourceCost[_level]/2;
        }
        lock = lockUpgradeResource(_level,damage);
    
    }

    function getBlocksToWin()
        external
        pure
        returns(uint)
    {
        return 20000;
    }

    function getInitialWarehouse()
        external
        pure 
        returns(uint, uint, uint)
    {
        return(10000,10000,10000);
    }
    
    function checkFleetRange(uint distance, uint fleetRange, uint mode, uint damage, bool battle)
        internal
        view
        returns(bool, uint)
    {
        uint distanceCanJump = fleetRange;
        uint lock;
        uint add;
        uint sub;
        bool inRange;

        (add,sub) = getDistanceBonusByMode(mode);
        if (add != 0) {
            distanceCanJump = distanceCanJump + (distanceCanJump * add / 100); 
        }
        if (sub != 0) {
            distanceCanJump = distanceCanJump - (distanceCanJump * sub / 100);
        }
        if (distanceCanJump >= distance) {
            inRange = true;
            lock = lockFleet(distance,battle,damage);
        }
        else
            inRange = false;

        return (inRange,lock);
    }


    function getFleetType(uint _attack, uint _defense, uint _distance, uint _load)
        internal
        pure
        returns(uint fleetType)
    {
        uint _d = _distance * 6;
        uint _l = _load/80;
        if ( _attack > _defense && _attack > _d && _attack > _l ) {
            fleetType = 1;
        }
        else {
            if (_defense > _attack && _defense > _d && _defense > _l) {
                fleetType = 2;
            }
            else {
                if ( _d > _attack && _d > _defense && _d > _l) {
                    fleetType = 3;
                }
                else {
                    if (_l > _attack && _l > _defense && _l > _d) {
                        fleetType = 4;
                    }
                    else {
                        fleetType = 5;
                    }
                }
            }
        }
    }

    function getCannonDamage(uint cannonLevel, uint distance)
        internal
        pure
        returns (uint)
    {
        return (cannonLevel * 5)/distance;
    }
    
    function getFireCannonCost()
        internal
        pure
        returns (uint)
    {
        return 2000000;
    }

    function portCombarCalcInternal(uint aPoints, uint aSize, uint[5] dPoints, uint[5] dSize)
        internal
        pure
        returns(uint aRemain, uint[5] dRemain)
    { 
        uint attackerPoints = aPoints * aSize;
        uint defenderPoints;
        uint p;
        uint i;
        uint s;

        for (i = 0; i <= 4; i++) 
            defenderPoints = defenderPoints + (dPoints[i] * dSize[i]);
        
        if (defenderPoints == 0)
            defenderPoints = 1;

        if (attackerPoints > defenderPoints) {
            // Gano el atacante
            s = 100-(100*defenderPoints/attackerPoints);
            if ( s != 0 ) {
                aRemain = s*aSize/100;
                if (aRemain == 0)
                    aRemain = 1;
            } else {
                aRemain = aSize;
            }
            for ( i = 0; i <= 4; i++ ) 
                dRemain[i] = 0;
        } else {
            // Gano el defensor
            s = defenderPoints - attackerPoints;
            aRemain = 0;
            for (i = 0; i <= 4; i++) {
                if (dSize[i] == 0 || dPoints[i] == 0) {
                    dRemain[i] = 0;
                } else {
                    p = (dPoints[i] * dSize[i] * 100) / defenderPoints;
                    dRemain[i] = ((p * s) / 100) / dPoints[i];
                    if (dRemain[i] == 0)
                        dRemain[i] = 1;
                }
            }
        }
    }


    function shipCombatCalcInternal(uint attack, uint aSize, uint aMode, uint defense, uint dSize, uint dMode)
        internal
        pure
        returns(uint a, uint d)
    {
        uint[2] memory aBonus;
        uint[2] memory dBonus;
        uint attackerPoints = attack * aSize;
        uint defenderPoints = defense * dSize;
        uint s;

        (aBonus[0],aBonus[1]) = getAttackBonusByMode(aMode);
        (dBonus[0],dBonus[1]) = getDefenseBonusByMode(dMode);

        /*
         * Siempre pone 1 punto de defensa como minimo.
         * En la version 1.2 Una flota con ataque 0 ataca a un ship sin puntos de defensa
         * surge el error de dividir por 0
         */
        if (defenderPoints == 0)
            defenderPoints = 1;

        if (aBonus[0] != 0 && aBonus[1] == 0) {
            attackerPoints = attackerPoints + (aBonus[0]*attackerPoints/100);
        }
        if (aBonus[0] == 0 && aBonus[1] != 0) {
            attackerPoints = attackerPoints - (aBonus[1]*attackerPoints/100);
        }
        if (dBonus[0] != 0 && dBonus[1] == 0) {
            defenderPoints = defenderPoints + (dBonus[0]*defenderPoints/100);
        }
        if (dBonus[0] == 0 && dBonus[1] != 0) {
            defenderPoints = defenderPoints - (dBonus[1]*defenderPoints/100);
        }
        
        /*
         * Gana el Atacante
         */
        if (attackerPoints > defenderPoints) 
        {
            s = 100-(100*defenderPoints/attackerPoints);
            if ( s != 0 ) {
                a = s*aSize/100;
                if (a == 0)
                    a = 1;
            } else {
                a = aSize;
            }
            d = 0;
        } else {
            s = 100-(100*attackerPoints/defenderPoints);
            if ( s != 0 ) {
                a = 0;
                d = s*dSize/100;
                if (d == 0 && dSize != 0)
                    d = 1;
            } else {
                a = 0;
                if (d == 0 && dSize != 0)
                    d = 1;
            }
        }
    }

    // Mode 0: Default    
    // Mode 1: Movemment: -10% Attack, -10% Defense, +50% Movemment
    // Mode 2: Attack:    +10% Attack, +50% distance, -10% Defense, -25%Movemment
    // Mode 3: Defense:   +30% Defense, -10% Attack, -100% Movemment
    
    function getMovemmentByMode(uint _mode)
        internal
        pure 
        returns(uint) 
    {
        uint8[4] memory movemmentPerMode = [4,6,3,0];
        return movemmentPerMode[_mode];
    }
    
       
    function getAttackBonusByMode(uint _mode)
        internal
        pure
        returns(uint,uint)
    {
        if (_mode == 0) return (0,0);
        else if (_mode == 1) return (0,10);
        else if (_mode == 2) return (25,0);
        else return (0,10);
    }
    
    function getDefenseBonusByMode(uint _mode)
        internal
        pure
        returns(uint,uint)
    {
        if (_mode == 0) return (0,0);
        else if (_mode == 1) return (0,10);
        else if (_mode == 2) return (0,10);
        else return (30,0);
    }

    function getDistanceBonusByMode(uint _mode)
        internal
        pure
        returns (uint,uint)
    {
        if (_mode == 2) return(50,0);
        else if(_mode == 3) return(0,50);
        else return(0,0);
    }

    function lockUpgradeResource(uint level, uint damage) 
        internal
        view 
        returns(uint)
    {
        uint ret;
        ret = level * 160;
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }
    
    function lockUpgradeBuilding(uint level, uint damage)
        internal
        view 
        returns(uint)
    {
        uint ret;
        ret = level * 400;
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }
    
    function lockMovemment(uint distance, uint mode, uint damage)
        internal
        view
        returns(uint)
    {
        uint8[4] memory movemmentPerMode = [4,6,3,0];
        uint ret;
        ret = (distance*400/movemmentPerMode[mode]);
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }
    

    function lockFleet(uint distance, bool battle, uint damage) 
        internal 
        view 
        returns(uint)
    {
        uint ret;
        if (!battle) {
            ret = (distance * 25);
        }
        else {
            ret = (distance * 100);
        }
        if (damage > 0) {
            ret = ((100 + damage) * ret) / 100;
        }
        return block.number + ret;
    }

    function getProductionByLevel(uint level) 
        internal
        pure
        returns(uint) 
    {
        uint8[11] memory production = [0,1,2,3,4,7,10,14,20,28,40]; // ...56,80 = 80*12 = 
        /*
            56 Level 11
            80 Level 12
        */
        return production[level];
    }   
}
