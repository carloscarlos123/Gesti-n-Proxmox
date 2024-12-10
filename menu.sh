#! /bin/bash
clear

tput civis

asignar_usuario_pool(){
	local mostrar_pools=$(pvesh get /pools | awk '{print $2}' | tail -n +4)
	local mostrar_usuarios=$(pveum user list | awk '{print $2}' | tail -n +6 | awk -F "@" '{print $1}')
	echo -e "\e[36mEstos son los usuarios disponibles\e[0m"
	echo $mostrar_usuarios
	echo -e "\e[36mEstos son las pools disponibles\e[0m"
	echo $mostrar_pools

	echo
	read -p "¿Que usuario quieres utilizar? " usuario_elegido
	read -p "¿En que pool quieres ponerlo? " pool_elegida
	echo
	pveum acl modify /pool/$pool_elegida --roles PVEAdmin --users $usuario_elegido@pve
	echo -e "Usuario \e[31m$usuario_elegido\e[0m asociado a la pool \e[31m$pool_elegida\e[0m correctamente..."
}

crear_plantilla(){
	vm_disponibles=()
	local mvs=$(qm list | awk '{print $1}' | tail -n +2)
	for id in $mvs; do
		local es_plantilla=$(qm config $id | grep "template" | wc -l)
		if [ $es_plantilla -eq 0 ]; then
			pos=${#vm_disponibles[@]}
			vm_disponibles[$pos]=$id
		fi
	done
	echo -e "\e[36mEstas son las VMs que puedes convertir en plantilla\e[0m"
	echo ${vm_disponibles[@]}

	echo
	read -p "¿Qué VMs quieres convertir en plantilla? " vm_elegida
	echo
	qm template $vm_elegida
	echo -e "Plantilla con ID \e[31m$vm_elegida\e[0m creada correctamente..."
}

crear_clonacion() {
	plantillas_disponibles=()
	local mvs=$(qm list | awk '{print $1}' | tail -n +2)
	for id_plantilla in $mvs; do
		local es_plantilla=$(qm config $id_plantilla | grep "template" | wc -l)
		if [ $es_plantilla -ne 0 ]; then
			pos=${#plantillas_disponibles[@]}
			plantillas_disponibles[$pos]=$id_plantilla
		fi
	done
	echo -e "\e[36mEstas son las plantillas disponibles para clonacion\e[0m"
	echo ${plantillas_disponibles[@]}

	echo
	read -p "¿Qué plantillas quieres clonar? " plantilla_elegida
	read -p "¿Qué nombre quieres dar a la clonacion? " nombre_elegido
	echo

	for id in {100..100000}; do
		local id_existe=$(qm list | awk '{print $1}' | grep -w $id)
		if [ -z "$id_existe" ]; then
			local nuevo_id=$id
			break
		fi
	done
	qm clone $plantilla_elegida $nuevo_id --name $nombre_elegido --full
	echo -e "Clonacion con ID \e[31m$nuevo_id\e[0m y nombre \e[31m$nombre_elegido\e[0m creada correctamente..."
}

crear_cs() {
	local vms=$(qm list | awk '{print $1}' | tail -n +2)
	echo -e "\e[36mEstas son las VMs que puedes crear una copia de seguridad\e[0m"
	echo $vms
	echo
	read -p "¿Qué vm quieres crear una copia de seguridad? " vm_elegida2
	vzdump $vm_elegida2 --dumpdir /var/lib/vz/dump
	echo -e "Creación de copia de seguridad de \e[31m$vm_elegida2\e[0m creada correctamente..."
}

crear_cs_pool() {
	local pools=$(pvesh get /pools | awk '{print $2}' | tail -n +4)
	echo -e "\e[36mEstas son las pools que puedes crear una copia de seguridad\e[0m"
	echo $pools
	echo
	read -p "¿Qué pool quieres crear una copia de seguridad? " pool_elegida3
	local vm_pool=$(pvesh get /cluster/resources --type vm | grep "$pool_elegida3" | awk '{print $2}' | awk -F "/" '{print $2}')
	if [ -n "$vm_pool" ]; then
		for mvs in $vm_pool; do
			vzdump $mvs --dumpdir /var/lib/vz/dump
		done
		echo -e "Creación de copia de seguridad de \e[31m$pool_elegida3\e[0m creada correctamente..."
	else
		echo "Esta pool no tiene VMs asociadas"
	fi
}

listar_cs_pool() {
	for pool in $@; do
		local vm_pool=$(pvesh get /pools/$pool | grep -o 'qemu/[0-9]*"' | awk -F ":" '{print $1}' | awk -F "/" '{print $2}' | tr '"' " ")
		echo -e "\e[36mPool: $pool tiene esta(s) copia(s) de seguridad\e[0m"
		for vm in $vm_pool; do
			local cs=$(pvesm list local --vmid $vm | awk '{print $1}' | tail -n +2)
			echo $cs
		done
	done
}

listar_cs_usuario() {
	local mostrar_usuarios=$(pveum user list | awk '{print $2}' | tail -n +6 | awk -F "@" '{print $1}')
	echo -e "\e[36mEstos son los usuarios disponibles\e[0m"
	echo $mostrar_usuarios
	echo
	read -p "¿Qué usuario quieres ver su(s) copia(s) de seguridad? " usuario_elegido2
	local usuario_pool=$(pveum acl list | grep $usuario_elegido2 | awk '{print $2}' | awk -F "/" '{print $3}')
	echo $usuario_pool
	echo -e "\e[36mUsuario: $usuario_elegido2 tiene esta(s) copia(s) de seguridad\e[0m"
	listar_cs_pool $usuario_pool
}

imprimir_menu(){
	opcion_elegida=$1
	opciones=(
		"1) CREAR POOL"
		"2) LISTAR POOLS"
		"3) CREAR USUARIO"
		"4) LISTAR USUARIOS"
		"5) ASIGNAR USUARIO A POOL"
		"6) LISTAR POOLS DE LOS USUARIOS"
		"7) CREAR PLANTILLA DE UNA MV"
		"8) CREAR CLONACIÓN SOBRE PLANTILLA"
		"9) CREAR COPIA DE SEGURIDAD DE UNA MV"
		"10) CREAR COPIA DE SEGURIDAD DE UNA POOL"
		"11) LISTAR COPIAS DE SEGURIDAD DE UNA POOL"
		"12) LISTAR COPIAS DE SEGURIDAD DE UN USUARIO"
		"13) SALIR"
	)
	for opcion in ${!opciones[@]}; do
		if [ $(($opcion+1)) -eq $opcion_elegida ]; then
			echo -e "\e[44m${opciones[$opcion]}\e[0m"
		else
			echo ${opciones[$opcion]}
		fi
	done
}

menu() {
	echo
	echo -e "\e[32mMenú Proxmox\e[0m"
	echo "--------------------------"
	echo "Pulsa la tecla W para arriba y la tecla S para abajo"
	echo
	echo "---------------------------------------------"
	imprimir_menu $1 ;;
	echo "---------------------------------------------"
}

echo
echo -e "\e[31mGESTIÓN DE PROXMOX\e[0m"
echo -e "Pulsa cualquier tecla para continuar..."

quitar=0
opc=1
opcs=13

while [ $quitar -eq 0 ]; do
	read -rs -n1 tecla
	clear
	case $tecla in
		"s")
			if [ $opc -lt $opcs ]; then
				opc=$(($opc+1))
			fi ;;
		"w")
			if [ $opc -gt 1 ]; then
				opc=$(($opc-1))
			fi ;;
		"")
			case $opc in
				1)
					echo -e "\e[32mCrear pool\e[0m"
					read -p "Nombre de la pool que quieres crear: " pool_creada
					pvesh create /pools -poolid $pool_creada
					echo
					echo -e "Pool \e[31m$pool_creada\e[0m creada correctamente..." ;;
				2)
					echo -e "\e[32mListar Pools\e[0m"
					echo "------------------------"
					pvesh get /pools ;;
				3)
					echo -e "\e[32mCrear usuario\e[0m"
					read -p "Nombre del usuario que quieres crear: " usuario_creado
					pveum user add $usuario_creado@pve --password usuario
					echo
					echo -e "Usuario \e[31m$usuario_creado\e[0m creado correctamente..." ;;
				4)
					echo -e "\e[32mListar usuarios Proxmox\e[0m"
					echo "------------------------"
					pveum user list	;;
				5)
					echo -e "\e[32mAsignar usuario a pool\e[0m"
					echo "------------------------"
					asignar_usuario_pool ;;
				6)
					echo -e "\e[32mListar pools de los usuarios\e[0m"
					echo "------------------------"
					pveum acl list ;;
				7)
					echo -e "\e[32mCrear plantilla de una MV\e[0m"
					echo "------------------------"
					crear_plantilla ;;
				8)
					echo -e "\e[32mCrear clonación sobre plantilla\e[0m"
					echo "------------------------"
					crear_clonacion ;;
				9)
					echo -e "\e[32mCrear copia de seguridad de una MV\e[0m"
					echo "------------------------"
					crear_cs ;;
				10)
					echo -e "\e[32mCrear copia de seguridad de una pool\e[0m"
					echo "------------------------"
					crear_cs_pool ;;
				11)
					echo -e "\e[32mListar copias de seguridad de una pool\e[0m"
					echo "------------------------"
					pools=$(pvesh get /pools | awk '{print $2}' | tail -n +4)
					echo -e "\e[36mEstas son las pools que puedes ver la(s) copia(s) de seguridad\e[0m"
					echo $pools
					echo
					read -p "¿Qué pool quieres ver la copias de seguridad? " pool_elegida2
					listar_cs_pool $pool_elegida2 ;;
				12)
					echo -e "\e[32mListar copias de seguridad de un usuario\e[0m"
					echo "------------------------"
					listar_cs_usuario ;;
				13)
					quitar=1
					tput cnorm ;;
			esac ;;
		*)
			clear ;;
	esac
	menu $opc
done
