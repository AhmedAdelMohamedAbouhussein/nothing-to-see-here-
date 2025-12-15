import { useState } from 'react';
import { Link } from 'react-router-dom';
import { FaCaretLeft, FaCaretRight, FaDesktop, FaFileAlt } from "react-icons/fa";

import styles from './Navbar.module.css';

function Navbar() {
    const [isOpen, setIsOpen] = useState(true);

    const toggleNavbar = () => {
        setIsOpen(!isOpen);
    };

    const handleSidebarClick = () => {
        if (!isOpen) setIsOpen(true);
    };

    return (
        <div
            className={`${styles.navbar} ${!isOpen ? styles.hide : ''}`}
            onClick={handleSidebarClick}
        >
            <div className={styles.content}>
                <div className={styles.top}>
                    <h3>Menu</h3>
                    <div className={styles.arrow} onClick={toggleNavbar}>
                        {isOpen ? <FaCaretLeft /> : <FaCaretRight />}
                    </div>
                </div>

                <div className={styles.items}>
                    <ul className={styles.ulist}>
                        <li className={styles.listitems}>
                            < FaDesktop className={styles.icons} />
                            <Link className={styles.links} to="/">Monitor</Link>
                        </li>
                        <li className={styles.listitems}>
                            < FaFileAlt className={styles.icons} />
                            <Link className={styles.links} to="/report">Reports</Link>
                        </li>
                    </ul>
                </div>
            </div>
        </div>
    );
}

export default Navbar;
